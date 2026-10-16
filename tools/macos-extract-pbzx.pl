#!/usr/bin/env perl

use strict;
use warnings;

my ($input, $output) = @ARGV;
die "Usage: perl $0 input.pbzx output.cpio\n"
    unless defined $input && defined $output;

open my $in, '<:raw', $input or die "Open $input: $!";
open my $out, '>:raw', $output or die "Create $output: $!";

sub read_exact {
    my ($fh, $len) = @_;
    my $buf = '';

    while (length($buf) < $len) {
        my $n = read($fh, my $part, $len - length($buf));
        die "Unexpected EOF\n" unless defined($n) && $n > 0;
        $buf .= $part;
    }
    return $buf;
}

sub read_u64be {
    my ($fh) = @_;
    my ($hi, $lo) = unpack('NN', read_exact($fh, 8));

    # Reject implausibly large lengths before allocating memory.
    die "Unsupported 64-bit length\n" if $hi > 1;
    return $hi * 4294967296 + $lo;
}

my $magic = read_exact($in, 4);
die "Not a pbzx payload\n" unless $magic eq 'pbzx';

my $block_size = read_u64be($in);
die "Invalid block size: $block_size\n"
    if $block_size < 1 || $block_size > 1073741824;

my $chunk_no = 0;
my $total_out = 0;

while (1) {
    my $n = read($in, my $first, 1);
    die "Read error: $!\n" unless defined $n;
    last if $n == 0;

    my $header = $first . read_exact($in, 15);
    my ($usize_hi, $usize_lo, $csize_hi, $csize_lo) =
        unpack('NNNN', $header);

    die "Chunk size too large\n"
        if $usize_hi > 1 || $csize_hi > 1;

    my $usize = $usize_hi * 4294967296 + $usize_lo;
    my $csize = $csize_hi * 4294967296 + $csize_lo;

    die "Invalid chunk lengths\n"
        if $usize < 1
        || $csize < 1
        || $usize > $block_size
        || $csize > 1073741824;

    my $data = read_exact($in, $csize);
    my $written = 0;
    ++$chunk_no;

    if ($csize == $usize) {
        print {$out} $data or die "Writing output failed: $!\n";
        $written = length($data);
    } else {
        my $tmp = "/tmp/pbzx-chunk-$$-$chunk_no.xz";

        open my $tf, '>:raw', $tmp or die "Create $tmp: $!";
        print {$tf} $data or die "Write $tmp: $!";
        close $tf or die "Close $tmp: $!";

        open my $xz, '-|', '/usr/bin/xz', '-dc', $tmp
            or die "Cannot start xz: $!";

        binmode $xz;
        while (1) {
            my $r = read($xz, my $buf, 65536);
            die "Reading xz output failed\n" unless defined $r;
            last if $r == 0;

            print {$out} $buf or die "Writing output failed: $!\n";
            $written += $r;
        }

        close $xz;
        my $status = $?;
        unlink $tmp;

        die "xz failed on chunk $chunk_no (status $status)\n"
            if $status != 0;
    }

    die "Chunk $chunk_no size mismatch: got $written, expected $usize\n"
        if $written != $usize;

    $total_out += $written;
    printf STDERR "Decoded chunk %d: %d bytes\n", $chunk_no, $written;
}

close $in or die "Closing input failed\n";
close $out or die "Closing output failed\n";

printf STDERR "Done: %d chunks, %d output bytes\n",
    $chunk_no, $total_out;
