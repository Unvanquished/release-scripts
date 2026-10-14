#!/usr/bin/env perl

use strict;
use warnings;

use Cwd qw(abs_path getcwd);
use File::Basename qw(basename);
use File::Find ();
use File::Path qw(make_path);
use File::Spec;
use File::Temp qw(tempdir);

# ------------------------------------------------------------
# Configuration and basic helpers
# ------------------------------------------------------------

sub fail {
    die "ERROR: $_[0]\n";
}

# Avoid Apple's Perl version-selector warning in child processes.
delete $ENV{VERSIONER_PERL_VERSION};

@ARGV == 2 or fail(
    "Usage: $0 input.dmg output-directory"
);

my $input_arg = $ARGV[0];
my $output_arg = $ARGV[1];

my $input = abs_path($input_arg);
defined($input) && -f $input
    or fail("Input DMG does not exist or is not a regular file: $input_arg");

use FindBin qw($RealBin);
my $decoder = $ENV{CLT_PBZX_DECODER} || "$RealBin/macos-extract-pbzx.pl";
-f $decoder
    or fail("PBZX decoder not found: $decoder");

$decoder = abs_path($decoder);

sub find_executable {
    my ($name) = @_;

    if ($name =~ m{/}) {
        return abs_path($name) if -f $name && -x $name;
        return;
    }

    for my $dir (split(/:/, $ENV{PATH} || '')) {
        $dir = '.' if $dir eq '';

        my $candidate = File::Spec->catfile($dir, $name);
        return abs_path($candidate)
            if -f $candidate && -x $candidate;
    }

    return;
}

sub resolve_program {
    my ($name) = @_;

    my $found = find_executable($name);
    return $found if defined $found;

    return;
}

sub run {
    my (@cmd) = @_;

    print "  + ", join(' ', @cmd), "\n";

    my $rc = system { $cmd[0] } @cmd;

    $rc != -1
        or fail("Cannot execute $cmd[0]: $!");

    ($rc & 127) == 0
        or fail(sprintf(
            "Command died from signal %d: %s",
            $rc & 127, $cmd[0]
        ));

    my $exit = $rc >> 8;

    $exit == 0
        or fail("Command exited with status $exit: $cmd[0]");
}

sub wait_for_child {
    my ($pid, $description) = @_;

    my $waited = waitpid($pid, 0);

    $waited == $pid
        or fail("waitpid failed while $description: $!");

    my $status = $?;

    $status != -1
        or fail("Could not obtain child status while $description");

    ($status & 127) == 0
        or fail(sprintf(
            "Child died from signal %d while %s",
            $status & 127, $description
        ));

    my $exit = $status >> 8;

    $exit == 0
        or fail("Child exited with status $exit while $description");
}

# ------------------------------------------------------------
# Locate 7-Zip
# ------------------------------------------------------------

my $sevenzip;

if (defined $ENV{CLT_7ZIP} && $ENV{CLT_7ZIP} ne '') {
    $sevenzip = resolve_program($ENV{CLT_7ZIP});
    defined $sevenzip
        or fail("Cannot execute CLT_7ZIP=$ENV{CLT_7ZIP}");
}

if (!defined $sevenzip) {
    $sevenzip = resolve_program('7z')
        || resolve_program('7zz');
}

defined $sevenzip
    or fail("Cannot find 7zz or 7z in PATH");

my $cpio = resolve_program('cpio');
defined $cpio
    or fail("Cannot find cpio in PATH");

my $xz = resolve_program('xz');
defined $xz
    or fail("Cannot find xz in PATH");

# Use the same cpio executable for listing and extraction.
# The PBZX decoder uses xz from PATH.

# ------------------------------------------------------------
# Prepare output directory
# ------------------------------------------------------------

my $output = File::Spec->rel2abs($output_arg);

if (-e $output) {
    -d $output
        or fail("Output path exists but is not a directory: $output");

    opendir(my $dh, $output)
        or fail("Cannot open output directory: $output: $!");

    my @entries = grep {
        $_ ne '.' && $_ ne '..'
    } readdir($dh);

    closedir($dh);

    @entries == 0
        or fail("Output directory is not empty: $output");
}
else {
    make_path($output)
        or fail("Cannot create output directory: $output");
}

my $root = File::Spec->catdir($output, 'root');

make_path($root)
    or fail("Cannot create extraction root: $root");

my $work = tempdir(
    'clt-extract-XXXXXXXX',
    TMPDIR  => 1,
    CLEANUP => 1,
);

my $dmg_tree = File::Spec->catdir($work, 'dmg');
my $pkg_tree = File::Spec->catdir($work, 'packages');

make_path($dmg_tree, $pkg_tree);

print "Input DMG: $input\n";
print "Output:    $root\n";
print "7-Zip:     $sevenzip\n";
print "CPIO:      $cpio\n";
print "Work dir:  $work\n";

# ------------------------------------------------------------
# Find files recursively
# ------------------------------------------------------------

sub find_matching {
    my ($base, $predicate) = @_;

    my @found;

    return @found unless -d $base;

    File::Find::find(
        {
            no_chdir => 1,
            wanted   => sub {
                my $path = $File::Find::name;
                return unless $predicate->($path);
                push @found, $path;
            },
        },
        $base,
    );

    return sort @found;
}

sub all_pkg_files {
    my ($base) = @_;

    return find_matching($base, sub {
        my ($path) = @_;

        return 0 unless -f $path;
        return basename($path) =~ /\.pkg\z/i;
    });
}

sub all_payloads {
    my ($base) = @_;

    return find_matching($base, sub {
        my ($path) = @_;

        return 0 unless -f $path;
        return basename($path) eq 'Payload';
    });
}

sub read_magic {
    my ($path) = @_;

    open(my $fh, '<:raw', $path)
        or fail("Cannot open file: $path: $!");

    my $magic = '';
    my $n = read($fh, $magic, 6);

    close($fh);

    defined($n) && $n == 6
        or return '';

    return $magic;
}

# ------------------------------------------------------------
# Expand the DMG
# ------------------------------------------------------------

print "\n==> Extracting DMG\n";

run(
    $sevenzip,
    'x',
    $input,
    "-o$dmg_tree",
    '-y',
);

# ------------------------------------------------------------
# Recursively expand .pkg archives.
#
# Apple packages may contain other .pkg archives. Continue
# scanning until no previously unseen package files remain.
# ------------------------------------------------------------

print "\n==> Expanding nested packages\n";

my %seen_pkg;
my $pkg_number = 0;

while (1) {
    my @candidates = (
        all_pkg_files($dmg_tree),
        all_pkg_files($pkg_tree),
    );

    my @pending;

    for my $pkg (@candidates) {
        next if $seen_pkg{$pkg};
        $seen_pkg{$pkg} = 1;
        push @pending, $pkg;
    }

    last unless @pending;

    for my $pkg (@pending) {
        ++$pkg_number;

        my $dest = File::Spec->catdir(
            $pkg_tree,
            "pkg-$pkg_number",
        );

        make_path($dest);

        print "\n==> Expanding package: $pkg\n";

        run(
            $sevenzip,
            'x',
            $pkg,
            "-o$dest",
            '-y',
        );
    }
}

# ------------------------------------------------------------
# Validate CPIO member paths before extraction.
#
# This avoids accepting absolute paths or '..' path components.
# Only use this extractor on trusted package files: path checks
# alone cannot protect against every malicious symlink archive.
# ------------------------------------------------------------

sub validate_cpio_paths {
    my ($archive, $list_file) = @_;

    my $pid = fork();

    defined $pid
        or fail("Cannot fork to list CPIO archive: $archive");

    if ($pid == 0) {
        open(STDIN, '<', $archive)
            or die "open $archive: $!\n";

        open(STDOUT, '>', $list_file)
            or die "open $list_file: $!\n";

        exec { $cpio } $cpio, '-it'
            or die "exec cpio: $!\n";
    }

    wait_for_child($pid, "listing CPIO archive $archive");

    open(my $fh, '<', $list_file)
        or fail("Cannot read CPIO listing: $list_file");

    while (my $line = <$fh>) {
        chomp($line);
        $line =~ s/\r\z//;

        next if $line eq '';

        # Some cpio implementations print a block count.
        next if $line =~ /\A\d+\s+blocks?\z/;

        if ($line =~ m{\A/}) {
            close($fh);
            fail("Unsafe absolute path in CPIO archive: $line");
        }

        if ($line =~ m{(?:\A|/)\.\.(?:/|\z)}) {
            close($fh);
            fail("Unsafe '..' path in CPIO archive: $line");
        }
    }

    close($fh);
}

# ------------------------------------------------------------
# Extract a CPIO archive under the output root.
# ------------------------------------------------------------

sub extract_cpio {
    my ($archive, $description) = @_;

    my $list_file = "$work/cpio-list-$$.txt";

    print "  Checking archive paths...\n";

    validate_cpio_paths($archive, $list_file);

    unlink($list_file);

    my $pid = fork();

    defined $pid
        or fail("Cannot fork for CPIO extraction: $description");

    if ($pid == 0) {
        chdir($root)
            or die "chdir $root: $!\n";

        open(STDIN, '<', $archive)
            or die "open $archive: $!\n";

        exec { $cpio } $cpio, '-idm'
            or die "exec cpio: $!\n";
    }

    wait_for_child($pid, "extracting $description");
}

# ------------------------------------------------------------
# Locate and extract payloads
# ------------------------------------------------------------

my @payloads = (
    all_payloads($dmg_tree),
    all_payloads($pkg_tree),
);

@payloads
    or fail("No Payload files found; is this a Command Line Tools DMG?");

my $payload_count = 0;
my $extracted_count = 0;

for my $payload (@payloads) {
    ++$payload_count;

    print "\n==> Payload $payload_count: $payload\n";

    my $magic = read_magic($payload);

    if ($magic eq '') {
        print "  Skipping empty or short payload\n";
        next;
    }

    my $cpio_file;

    if (substr($magic, 0, 4) eq 'pbzx') {
        $cpio_file = File::Spec->catfile(
            $work,
            "payload-$payload_count.cpio",
        );

        print "  Decoding PBZX payload\n";

        run(
            $^X,
            $decoder,
            $payload,
            $cpio_file,
        );

        my $decoded_magic = read_magic($cpio_file);

        $decoded_magic =~ /\A(?:070701|070702|070707)/
            or fail("PBZX decoder did not produce a recognized CPIO archive: $payload");
    }
    elsif ($magic =~ /\A(?:070701|070702|070707)/) {
        $cpio_file = $payload;
    }
    else {
        print "  Skipping unrecognized payload format\n";
        next;
    }

    extract_cpio($cpio_file, "payload $payload_count");

    unlink($cpio_file) if $cpio_file ne $payload;

    ++$extracted_count;
}

# ------------------------------------------------------------
# Report what was extracted
# ------------------------------------------------------------

print "\n==> Extraction summary\n";
print "Payloads found:     $payload_count\n";
print "Payloads extracted: $extracted_count\n";
print "Output root:        $root\n";

my @clang_files = find_matching($root, sub {
    my ($path) = @_;
    return 0 unless basename($path) eq 'clang';
    return -f $path;
});

if (@clang_files) {
    print "\nClang candidates:\n";

    for my $path (@clang_files) {
        print "  $path\n";
    }
}
else {
    print "\nWARNING: No file named clang was found in the extracted payloads.\n";
}

my @sdk_dirs = find_matching($root, sub {
    my ($path) = @_;

    return 0 unless -d $path;
    return basename($path) =~ /\A(?:MacOSX|iPhoneOS|iPhoneSimulator).*\.sdk\z/;
});

if (@sdk_dirs) {
    print "\nSDK directories:\n";

    for my $path (@sdk_dirs) {
        print "  $path\n";
    }
}

print "\nDone.\n";
