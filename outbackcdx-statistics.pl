#!/bin/perl
#
# A tool to collect statistics for WARC files indexed by OutbackCDX
#
# Copyright © 2022 National Library of Sweden (https://www.kb.se/)
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
use strict;
use warnings;
use Time::Piece;

sub usage {
    my $status = shift;
    my $message = shift;
    my ($script) = $0 =~ m|.*/(.*)|;
    print "ERROR: $message\n\n" if $message;

    print "usage: $script [<options>] [<output>] [<collection> ...]\n";
    print "   or: $script --in <path> [<output>] [<filters>]\n";
    print "   or: $script --help\n";
    print "\n";
    print " where <options> are\n";
    print "      -O | --outbackDir <path>       directory for OutbackCDX indexes (default: '/data/outbackcdx')\n";
    print "      -H | --outbackHost <string>    hostname for OutbackCDX (default: 'localhost')\n";
    print "      -P | --outbackPort <int>       port for OutbackCDX (default: 8085)\n";
    print " and <output> are zero or more of\n";
    print "      -o | --outfile <path>          path to output CSV-file\n";
    print "      -9 | --tab                     use TAB instead of ', ' as output separator\n";
    print " and <filters> are zero or more of\n";
    print "      -y | --year                    use year instead of month\n";
    print "      -m | --maintype                use only the first part of the content-type\n";
    print "      -a | --ascii                   use only an initial ascii part of malformed content-types\n";
    print "      -r | --rfc                     allow only RFC-compliant content-types (but allowing empty sub-types)\n";
    print "      -s | --start <timestamp>       only include data after timestamp (inclusive)\n";
    print "      -e | --end <timestamp>         only include data before timestamp (inclusive)\n";
    print "      -c | --collections <re>        only display collections matching given regexp(s) (repeatable)\n";
    print "      -d | --domains <re>            only display top level domains matching given regexp(s) (repeatable)\n";
    print "      -b | --sub-domains <re>        only display 2nd level domains matching given regexp(s) (repeatable)\n";
    print "      -t | --types <re>              only display content-types matching given regexp(s) (repeatable)\n";
    print "      -x | --extensions <re>         only display file name extensions matching given regexp(s) (repeatable)\n";
    print "      -C | --total-collections       merge data for all collections\n";
    print "      -D | --total-domains           merge data for all top level domains\n";
    print "      -B | --total-sub-domains       merge data for all second level domains\n";
    print "      -T | --total-types             merge data for all content-types\n";
    print "      -X | --total-extensions        merge data for all file name extensions\n";
    print "      -M | --total-months            merge data for all months\n";
    print "      -A | --total                   merge data for all key columns (alias for -CDBTXM)\n";
    print "\n";
    print "If no infile is given, the raw CDX data is read from OutbackCDX and the statistics are printed as CSV.\n";
    print "If an infile is given, the statistics within are recalculated according to specified filters.\n";
    print "The infile is expected to be a previously generated CSV-file.\n";
    print "If the infile has an extension of either '.gz' or '.bz2', it will be decompressed while reading.\n";
    print "If the outfile has an extension of either '.gz' or '.bz2', it will be compressed after completely written.\n";
    print "\n";
    print "The columns reported are 'collection', 'top-level-domain', 'sub-domain', 'month', 'content-type',\n";
    print "'extension', 'count', 'size' and 'human-readable-size'.\n";
    print "Note that both 'size' and 'human-readable-size' represent the compressed size of the collected data.\n";
    exit $status;
}

my $startUrl = '';
my ($infile, $outfile, $tmpfile);
my $year = 0;
my $main = 0;
my $ascii = 0;
my $rfc = 0;
my $start = '000000';
my $end = '999999';
my $c = ', ';
my $outbackHost = "localhost";
my $outbackPort = "8085";
my $outbackDir = "/data/outbackcdx";
my (@domains, @subDomains, @types, @extensions, @collections);
my ($mergeCollections, $mergeDomains, $mergeSubdomains, $mergeTypes, $mergeExtensions, $mergeMonths);
use Getopt::Long qw(:config auto_version bundling);
GetOptions(
    'u|url=s'=>\$startUrl,
    'o|out|outfile=s'=>\$outfile,
    'i|f|in|infile=s'=>\$infile,
    '9|tab'=>sub {$c = "\t"},
    'O|outbackDir=s'=>\$outbackDir,
    'H|host|outbackHost=s'=>\$outbackHost,
    'P|port|outbackPort=s'=>\$outbackPort,
    'y|year'=>\$year,
    'm|maintype'=>\$main,
    'a|ascii'=>\$ascii,
    'r|rfc'=>\$rfc,
    's|start=s'=>\$start,
    'e|end=s'=>\$end,
    'c|collections=s'=>\@collections,
    'd|domains=s'=>\@domains,
    'b|sub-domain=s'=>\@subDomains,
    't|types=s'=>\@types,
    'x|extensions=s'=>\@extensions,
    'C|total-collections'=>\$mergeCollections,
    'D|total-domains'=>\$mergeDomains,
    'B|total-sub-domains'=>\$mergeSubdomains,
    'T|total-types'=>\$mergeTypes,
    'X|total-extensions'=>\$mergeExtensions,
    'M|total-months'=>\$mergeMonths,
    'A|total|total-all'=>sub {$mergeCollections = $mergeDomains = $mergeSubdomains = $mergeTypes = $mergeExtensions = $mergeMonths = 1},
    'h|help'=> sub {usage(0)}
) or die usage(1);

usage(2, "all filter options require '--in'") if not $infile and (
    $year or $main or $ascii or $rfc or $start ne '000000' or $end ne '999999' or
    @domains or @subDomains or @types or @extensions or @collections or
    $mergeCollections or $mergeDomains or $mergeSubdomains or $mergeTypes or $mergeExtensions or $mergeMonths);
usage(3, "the '--in' and '--url' options are incompatible") if $infile and $startUrl;
usage(4, "the '--in' and '--out' options may not be identical") if $infile and $outfile and $infile eq $outfile and $infile ne '-';

@collections = @ARGV unless @collections;

if ($outfile and $outfile ne '-') {
    $tmpfile = "$outfile-in-progress";
    open STDOUT, '>', "$tmpfile" or die "ERROR: failed to open file '$tmpfile' for writing";
}

if ($infile) { # re-caclulated previously collected statistics
    my %stat;
    my $collections = join '|', @collections;
    my $domains = join '|', map {split ','} @domains;
    my $subDomains = join '|', map {split ','} @subDomains;
    my $types = join '|', map {split ','} @types;
    my $extensions = join '|', map {split ','} @extensions;
    my $separator;

    if ($infile =~ /\.gz$/) {
        open STDIN, '-|', 'gzip', '-dc', $infile or die "ERROR: failed to start 'gzip -dc $infile'\n";
    } elsif ($infile =~ /\.bz2$/) {
        open STDIN, '-|', 'bzip2', '-dc', $infile or die "ERROR: failed to run 'bzip2 -dc $infile'\n";
    } elsif ($infile ne "-") {
        open STDIN, '<', $infile or die "ERROR: failed to open file '$infile'\n";
    }

    while (<>) {
        chomp;
        s/"//g;
        $separator = /, / ? ", " : "\t" unless $separator;
        my ($coll, $tld, $sld, $ts, $type, $ext, $count, $size, $human) = split(/$separator/);
        # check for previous file format
        ($sld, $ts, $type, $ext, $count, $size) = ('*', $sld, $ts, $type, $ext, $count) unless defined $human;
        warn "BAD DATA: '$_'\n" and next unless $size;

        next if $collections and $coll !~ /$collections/;
        next if $domains and $tld !~ /$domains/;
        next if $subDomains and $sld !~ /$subDomains/;
        next if $types and $type !~ /$types/;
        next if $extensions and $ext !~ /$extensions/;
        next if $ts lt $start or $ts gt "${end}99";
        $ts =~ s/..$// if $year;
        $type = lc $type;
        $type =~ s|/.*|| if $main;
        $type =~ s|[^[:print:]].*$|| if $ascii;
        $type = &rfc($type) if $rfc;
        $type ||= '-';
        $coll = '*' if $mergeCollections;
        $tld  = '*' if $mergeDomains;
        $sld  = '*' if $mergeSubdomains;
        $ts   = '*' if $mergeMonths;
        $type = '*' if $mergeTypes;
        $ext  = '*' if $mergeExtensions;

        $stat{$coll}{$tld}{$sld}{$ts}{$type}{$ext}[0] += $count;
        $stat{$coll}{$tld}{$sld}{$ts}{$type}{$ext}[1] += $size;
    }

    # output the filtered data
    for my $coll (sort keys %stat) {
        for my $tld (sort keys %{$stat{$coll}}) {
            for my $sld (sort keys %{$stat{$coll}{$tld}}) {
                &out($coll, $tld, $sld, $stat{$coll}{$tld}{$sld});
            }
        }
    }

} else { # fetch CDX data and print statistics

    @collections = grep {-d} glob("$outbackDir/*") unless @collections;

    for my $collection (@collections) {
        $collection =~ s|.*/||;

        my $matchType = $startUrl ? 'domain' : 'range';
        $matchType = 'exact' if $startUrl =~ m|/|; # fetch just one url for debugging
        $matchType = 'range' if $startUrl =~ m|\.$|; # allow starting over from a specified domain
        (my $lastTld = $startUrl) =~ s/\.?$//;
        $lastTld =~ s/^(.+)\.([^.]+)$/$2/;
        my $lastSld = $1 // '';

        {
            my $found;
            my $last = $lastSld ? "$lastSld.$lastTld" : $lastTld;
            my $search = "http://$outbackHost:$outbackPort/$collection?url=$last&matchType=$matchType&filter=status:200";
            my $now = localtime->strftime("%FT%T");
            warn "$now: curl -sSf '$search'\n";
            open CURL, '-|', 'curl', '-sSf', "$search";
            my %stat;
            while (<CURL>) {
                s/"//g;
                my ($tld, $ts, $url, $type, $status, $idk0, $idk1, $idk2, $size, $offset, $file) = split(/ /);
                next if $tld =~ /^dns:/;

                # verify data completeness
                unless ($size =~ /^\d+$/) {
                    warn "BAD DATA: '$_' in $collection\n";
                    $size = 0;
                }

                # get extension from end of url
                my $ext = $tld;
                $ext =~ s|^.*/||;
                $ext =~ s|\?.*$||;
                unless ($ext =~ s/.*\.([[:alnum:]]{1,5})$/$1/ and $ext =~ /[[:alpha:]]/) {
                    $ext = '-';
                }

                # extract top and 2nd level domain
                my $sld;
                if ($tld =~ /^\d+\.\d+\.\d+\.\d+/) {
                    $tld = 'IP';
                    $sld = '';
                } elsif ($tld =~ m|^([[:alnum:]-]+)(,([^,/)]+))?|) { # dash to allow punycode
                    $tld = $1;
                    $sld = $3 // '';
                } else {
                    warn "UNEXPECTED DOMAIN: '$_' in $collection\n";
                    $tld = $lastTld;
                    $sld = $lastSld;
                }

                # truncate timestamp
                $ts =~ s/^(\d{6})\d+/$1/;

                # make content-type lower case
                $type ||= '-';
                $type = lc $type;
                # make sure data doesn't contain separator characters
                $type =~ s/\t|, /;/g;

                # unify common extensions
                $ext = 'jpg' if $ext eq 'jpeg';
                $ext = 'html' if $ext eq 'htm';
                $ext = '-' if $ext eq $tld and $type eq 'text/html';

                # output previous complete top level domain
                if ($tld ne $lastTld or $sld ne $lastSld) {
                    &out($collection, $lastTld, $lastSld, \%stat);
                    $lastTld = $tld;
                    $lastSld = $sld;
                    %stat = ();
                }

                # sum up statistics
                $stat{$ts}{$type}{$ext}[0] ++;
                $stat{$ts}{$type}{$ext}[1] += $size;

                $found = 1;
            }

            unless (close CURL) {
                # skip bad collection
                warn "ERROR: curl failed before first line of data from '$collection'\n" and next unless $found;
                # handle OutbackCDX restart
                %stat = ();
                $lastTld = $lastSld = '' if $lastTld eq 'IP';
                $lastTld = $startUrl if $matchType ne 'range';
                warn "WARNING: curl failed - restarting from '$last' in '$collection'\n";
                sleep 3; # give OutbackCDX some time to start again
                redo; # repeat from last incomplete domain
            }
           # output last block of data
            &out($collection, $lastTld, $lastSld, \%stat);
        }
    }
}

# rename and optionaly compress outfile when complete
if ($outfile) {
    die "ERROR: no data written to '$tmpfile'\n" if -z $tmpfile;
    my $now = localtime->strftime("%FT%T");
    if ($outfile =~ /\.gz/) {
        warn "$now: compressing '$tmpfile'\n";
        system "gzip $tmpfile";
        $tmpfile .= '.gz';
    } elsif ($outfile =~ /\.bz2/) {
        warn "$now: compressing '$tmpfile'\n";
        system "bzip2 $outfile-in-progress";
        $tmpfile .= '.bz2';
    }
    rename "$tmpfile", "$outfile";
}
my $now = localtime->strftime("%FT%T");
warn "$now: done.\n";

sub out {
    my $coll = shift or return;
    my $tld = shift or return;
    my $sld = shift or return;
    my $stat = shift or return;

    # output the data as CSV
    for my $ts (sort keys %$stat) {
        for my $type (sort keys %{$stat->{$ts}}) {
            for my $ext (sort keys %{$stat->{$ts}{$type}}) {
                my $count = $stat->{$ts}{$type}{$ext}[0];
                my $bytes = $stat->{$ts}{$type}{$ext}[1];
                my $human = &human($bytes);
                printf '"%s"%s"%s"%s"%s"%s"%s"%s"%s"%s"%s"%s%d%s%d%s"%s"'."\n",
                    $coll, $c, $tld, $c, $sld, $c, $ts, $c, $type, $c, $ext, $c, $count, $c, $bytes, $c, $human;
            }
        }
    }
    STDOUT->flush(); # don't buffer the output
}

sub human {
    # calculate largest unit that gives a mantissa larger than 1
    my $size = shift;
    my $unit = 0;
    my @units=<B KiB MiB GiB TiB PiB EiB ZiB YiB>;
    while ($size > 1024) {
        $size /= 1024;
        $unit++;
    }
    my $precision = !! $unit;
    return sprintf "%.*f %s", $precision, $size, $units[$unit];
}

sub rfc {
    # clean up non-RFC-compliant content-types - https://www.rfc-editor.org/rfc/rfc2045#section-5.1
    my $type = shift;
    if ($type =~ m|([^/]+)(/[^;]*)?|) {
        my ($mainType, $subType) = ($1, $2);
        $mainType =~ /^(application|audio|image|message|multipart|text|video|x-[[:print:]]+)$/ or $mainType = '';
        if ($mainType =~ /^x-/) {
            $mainType =~ /[[:cntrl:] <>@,:;?.=]/ and $mainType = '';
            $mainType =~ /[][()\\\/"]/ and $mainType = '';
        }
        $subType = '' unless $mainType;
        if ($subType) {
            $subType =~ s|^/||;
            $subType =~ /[[:cntrl:] <>@,:;?.=]/ and $subType = '';
            $subType =~ /[][()\\\/"]/ and $subType = '';
            $subType = "/$subType";
        }
        $type = $mainType;
        # but allow empty sub-type
        $type .= "$subType" if $subType;
    } else {
        $type = '';
    }
    $type =~ s|^(application/octet-stream).*|$1|;
    # default content-type is application/octet-stream
    $type ||= 'application/octet-stream';
    return $type;
}
