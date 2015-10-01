#!/usr/bin/perl
use Getopt::Long;

my $complement = 0;
my $patfrom = "";
my $patto = "";
GetOptions('v!'=>\$complement,
    'patfrom:s'=>\$patfrom,
    'patto:s'=>\$patto);

if (@ARGV != 2) {
    print "usage: cat input | $0 match.lst n > output\n";
    print "prints only those lines where the n-th column is a word in the match.lst file\n";
    print "Columns are based on tab-separation and are 1-based.\n";
    print "Options:\n";
    print "     --v   Use complement. Print all lines NOT matching.\n";
    print "     --patfrom --patto   Apply query replace regular expression to the entry in the n-th column first before checking for membership in the list.\n";
    print "                         Will use the pattern $entry =~ s/\$patfrom/\$patto/\n";
    print "                         Useful for removing modifications, e.g. tripping a trailing -1 before performing the check.\n";
    print "                         Both default to empty patterns.\n";
    exit(1);
}

my $matchfile = $ARGV[0];
my $n = $ARGV[1];
open (MATCH, "<$matchfile") or die ("Could not open $matchfile\n");

my %include = ();

while (<MATCH>) {
    chomp;
    $include{$_}++;
}
close MATCH;

while(<STDIN>) {
    chomp;
    @f = split /\t/;
    my $field = $f[$n-1];
    $field =~  s/$patfrom/$patto/;
    print $_ ."\n" if (($include{$field} && !$complement) || (!$include{$field} && $complement));
}
