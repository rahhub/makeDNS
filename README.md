# makeDNS

Generate DNS zone files from a hosts file

## Overview

I originally wrote makeDNS many years ago to generate DNS zone files 
from the hosts file I used on my NIS master server.

makeDNS is a Perl script which takes a traditional hosts file,
having records of the form:

```
# IP		primary-hostname alias-1 alias-2
127.0.0.1	localhost wwwtest smtp
```

and transforms it into a set of DNS zone files suitable for use with BIND
and other DNS servers.

All names are put into a single forward zone, the name of which is
configured in makeDNS itself. Reverse zone files are created for each /24
network containing at least one IP address in the hosts file. The 
generated zone files have the name of their zone.

## Configuration

As makeDNS was intended for use in static environments, the configuration
is defined within the script itself. Open the script in an editor and
you'll see a block near the top similar to:

```
# User configuration block

my $dom="home.rah.org";			# DNS domain for zone
my $priserver="services";		# Primary server name for SOA
my $mailaddr="hostmaster.rah.org";	# e-mail address for SOA

# Test Directories
my $dir="./test/named";			# Output directory
my $hostfile="./test/hosts";	# Hosts file to source

# Prod Directories
#my $dir="/var/named";			# Output directory
#my $hostfile="/etc/hosts";		# Hosts file to source

# End of user configuration block
```

The script is preconfigured for test use. You should be able to just
run

```
./makeDNS.pl
```

and it will generate zone files from the test
hosts file `./test/hosts` in the directory `./test/named`.

For production use, uncomment the following lines

```
# Prod Directories
#my $dir="/var/named";			# Output directory
#my $hostfile="/etc/hosts";		# Hosts file to source
```

and update to specify the current locations of these files on your
server.

You will need to copy the files `test/named/include/forward` and
`test/named/include/reverse` to a directory on your server called
`$dir/include` and add any records you want included, such as MX
or NS records, in every forward and reverse zone that is generated.