# OutbackCDX statistics collector

A tool to collect statistics for WARC files indexed in OutbackCDX

## Usage

```
./outbackcdx-statistics.pl [<options>]
```

Details on the `<options>` can be found by running

```
./outbackcdx-statistics.pl --help
```

## Description

Fetches the [OutbackCDX](https://github.com/nla/outbackcdx) index and prints the number
and size of stored objects for each collection, month, top level domain, 2nd level
domain, content-type and file extension.

Collection names are read from the OutbackCDX data directory unless given as arguments.

May optionally re-calculate previously collected data read from a CSV-file.

## Requirements

The tool needs a standard Perl 5.8 or later or an older Perl version plus the
Time::Piece module. Also HTTP access to an OutbackCDX index is required. Access to the
OutbackCDX data directory is needed to avoid having to type the collection names as
command line arguments. The `curl` command is used to fetch the CDX data and `gzip` or
`bzip2` is needed to compress and decompress the output and input files.

## Reason

The [National Library of Sweden](https://www.kb.se/) has [collected and archived web
sites](https://www.kb.se/hitta-och-bestall/hitta-i-samlingarna/kulturarw3.html) in the
`.se` top level domain since 1997. This tool was created to summarize statistics about
the collected data. Since other tools already created didn't fit our needs without
extra tooling we decided to create our own. For one thing the tools we found uses JSON
as output format which gives smaller file sizes compared to CSV but at the expense of
execution speed and memory consumption.

If someone else finds this tool useful we're happy to share - see below.

## Other CDX statistics tools

* https://github.com/internetarchive/cdx-summary
* https://github.com/ymaurer/cdx-summarize

## Source code

This tool can be found at https://github.com/krakan/outbackcdx-statistics/

## License

Copyright © 2022 [National Library of Sweden](https://www.kb.se/)

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

### Author

Jonas Linde <Jonas.Linde@kb.se>
