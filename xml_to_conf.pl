#!/usr/bin/perl
#
# $Id: xml_to_conf.pl,v 2.1 2005/04/14 19:23:40 horne Exp $
# $Revision: 2.1 $
# $Date: 2005/04/14 19:23:40 $
#

# Perl CGI common chunks
#
use strict ;
#no strict "vars";


#### work out where i am
# these 3 varables can then be used to find config files
# and keep the code portable

use FindBin qw($Bin $Script);
my ($BASE,$NAME)=($Bin,$Script) ;

use lib "$FindBin::Bin";

use XML::Parser;
use Data::Dumper;
use Getopt::Long;
use MIGRATION;

my $DEBUG ;
my $NO_OP ;
my $HELP ;

# may as well snarf the file from the server in the future.
GetOptions(
        "d=s"     => \$DEBUG,
        "h|help"  => \$HELP,
);

if ( ! @ARGV ) {
   print "Usage : $NAME <onedb.xml>
          use -d <num> for more detail
          ";
   exit ;
}


my $xfile = new XML::Parser(Style => 'Stream');
my $xfile = new XML::Parser(Handlers => 
                                     {
                                      Start=>\&handle_start,
                                      End=>\&handle_end,
                                     });

my %OBJ ;
my %DATA ;

# the zone tree is a branch leaf relation, that we store
# during the parsing

print "# Reading Config for $ARGV[0]\n";
$xfile->parsefile("$ARGV[0]");
print "# Read\n";

# we only care about /some/ types
my @parents = (
  ".com.infoblox.dns.zone",
  ".com.infoblox.dns.network",
);

my @net_leafs = (
  ".com.infoblox.dns.network_custom_option",
  ".com.infoblox.dns.network_domain_name_server",
  ".com.infoblox.dns.network_parent",
  ".com.infoblox.dns.network_router",
  ".com.infoblox.dns.shared_network_parent",
  ".com.infoblox.dns.dhcp_range",
  ".com.infoblox.dns.dhcp_range_domain_name_server",
);

my @host_types = (
  ".com.infoblox.dns.host",
  ".com.infoblox.dns.bind_a",
  ".com.infoblox.dns.bind_cname",
  ".com.infoblox.dns.bind_mx",
  ".com.infoblox.dns.bind_resource_record",
  ".com.infoblox.dns.bulk_host",
);

my @zone_leafs = (
  ".com.infoblox.dns.zone_delegated_server",
  ".com.infoblox.dns.host",
  ".com.infoblox.dns.host_address",
  ".com.infoblox.dns.bind_a",
  ".com.infoblox.dns.bind_cname",
  ".com.infoblox.dns.bind_mx",
  ".com.infoblox.dns.bind_ns",
  ".com.infoblox.dns.bind_resource_record",
  ".com.infoblox.dns.bind_soa",
  ".com.infoblox.dns.bulk_host",
);

my @globals = (
  ".com.infoblox.dns.cluster_dhcp_properties",
  ".com.infoblox.dns.cluster_dns_properties",
  ".com.infoblox.dns.member_dhcp_properties",
  ".com.infoblox.dns.member_dns_properties",
  ".com.infoblox.one.admin",
);

# now dump put some commands

# sput zones
my $key ='.com.infoblox.dns.zone' ;
print "#\n# $key\n#\n";

foreach my $oid ( sort keys %{ $DATA{$key} } ) {
   my $zone = $DATA{$key}{$oid} ;
   my $name = $zone->{'name'};

   # look for type...
   if ( $zone->{'zone_type'} eq "Dummy" ) { next }

   print "conf zone add $name";

   # [ ] dns.zone_delegated_server
   if ( $zone->{'zone_type'} eq "Delegated" ) { 
      
      my $dkey ='.com.infoblox.dns.zone_delegated_server' ;
      # walk the delegated servers
      foreach my $deleg ( @{ $DATA{$dkey}{$name} } ) {
         my $ns = $deleg->{'ds_name'};
         my $ip = $deleg->{'address'};
         print " delegated $ns $ip"
      }

   # [ ] dns.zone_forward_server

   }

   print "\n";
}

# sput hosts
my $key ='.com.infoblox.dns.host' ;
print "#\n# $key\n#\n";

foreach my $oid ( sort keys %{ $DATA{$key} } ) {
   my $host = $DATA{$key}{$oid} ;
   my $name = $host->{'name'};
   my $zone = $host->{'zone'};

   print "conf zone $zone add host $name";

   # walk the addresses
   my $akey ='.com.infoblox.dns.host_address' ;
   foreach my $addr ( @{ $DATA{$akey}{"$name.$zone"} } ) {
         my $ip = $addr->{'address'};
         print " $ip"
   }

   print "\n";
}

# sput bulk hosts
my $key ='.com.infoblox.dns.bulk_host' ;
print "#\n# $key\n#\n";

foreach my $oid ( sort keys %{ $DATA{$key} } ) {
   my $host = $DATA{$key}{$oid} ;
   my $name = $host->{'prefix'};
   my $zone = $host->{'zone'};
   my $fip = $host->{'start_address'};
   my $lip = $host->{'end_address'};

   print "conf zone $zone add bulk $name $fip $lip\n";
}

# sput A records
# sput CNAMES
# sput MX
# these can be grouped ??

foreach my $rkey (
             ".com.infoblox.dns.bind_a",
             ".com.infoblox.dns.bind_cname",
             ".com.infoblox.dns.bind_mx",
                 ) {

   print "#\n# $rkey\n#\n";
   foreach my $oid ( sort keys %{ $DATA{$rkey} } ) {

      my $rec = $DATA{$rkey}{$oid} ;

      my $zone = $rec->{'zone'};
      my $name = $rec->{'name'};
      my $value = $rec->{'address'} 
                  || $rec->{'canonical_name'} ;

      if ( $rec->{'mx'} ) {
         $value = "$rec->{'mx'} $rec->{'priority'}";
      }

      ( my $type = $rkey ) =~ s/.*dns\.bind_//;

      print "conf zone $zone add $type $name $value\n";
   }
}

# sput networks
my $key ='.com.infoblox.dns.network' ;
print "#\n# $key\n#\n";

foreach my $oid ( sort keys %{ $DATA{$key} } ) {
   my $net = $DATA{$key}{$oid} ;
   my $name = $net->{'network'};

   print "conf network add $name\n";

}

# sput ranges
my $key ='.com.infoblox.dns.dhcp_range' ;
print "#\n# $key\n#\n";

foreach my $oid ( sort keys %{ $DATA{$key} } ) {
   my $obj = $DATA{$key}{$oid} ;
   my $net = $obj->{'network'};
   my $fip = $obj->{'start_address'};
   my $lip = $obj->{'end_address'};

   print "conf network $net add range $fip $lip\n";

}


exit;

# as it is a flat file structure we need to shove all this into a series
# of hashes , keyed of something useful .

sub handle_start {
    my ($expat,$element, %attrs)=@_ ;

    # ask the expat object about our position
    my $line = $expat->current_line;

    # property objects are the name value pairs
    # the $OBJ hash is the current set of name value pairs
    # we will undef this when we get to a </OBJECT>

    if ( $element eq "PROPERTY" ) {
       # look for the name value pair
       if( %attrs ) {
           my $name = $attrs{'NAME'};
           my $value = $attrs{'VALUE'};

           # save it in the current OBJECT
           $OBJ{$name}=$value;
       }
    }
}

# process an end-of-element event
#
sub handle_end {
    my( $expat, $element ) = @_;

    if ( $element eq "OBJECT" ) {

       # now we need to save this %OBJ hash somewhere
       # we'll key off the type
       # then off the oid (which seems to be uniq)

       my $type = $OBJ{"__type"};
       my $oid = $OBJ{"oid"};

       # most of the objects we are looking for are scattered, so
       # we're going to have to stuff all this into hashes and post
       # process

       # and locate and store certain types
       # [ ] sput networks
       if ( $type eq ".com.infoblox.dns.network" ) {

          # ".com.infoblox.dns.network_custom_option",
          # ".com.infoblox.dns.network_domain_name_server",
          # ".com.infoblox.dns.network_parent",
          # ".com.infoblox.dns.network_router",
          # ".com.infoblox.dns.shared_network_parent",

          my $net = $OBJ{"address"};
          my $mask = $OBJ{"netmask"};
          my $cidr = masktocidr ( $mask ) ;
          # save it
          $OBJ{"network"}="$net/$cidr";

          $DATA{$type}{$oid} = { %OBJ } ;
       }

       # [ ] sput bulk hosts
       elsif ( $type eq ".com.infoblox.dns.bulk_host" ) {
          my $izone = &invert_name ( $OBJ{'zone'} ) ;
          $OBJ{'zone'} = $izone ;

          $DATA{$type}{$oid} = { %OBJ } ;

       }

       # [ ] sput hosts
       # [ ] sput A records
       # [ ] sput CNAMES
       # [ ] sput MX
       # [ ] dotted host names ?
       # [ ]   or $type eq ".com.infoblox.dns.bind_resource_record" 

       elsif (    $type eq ".com.infoblox.dns.host" 
               or $type eq ".com.infoblox.dns.bind_cname" 
               or $type eq ".com.infoblox.dns.bind_a" 
               or $type eq ".com.infoblox.dns.bind_mx" 
             ) {

          my $izone = &invert_name ( $OBJ{'zone'} ) ;
          $OBJ{'zone'} = $izone ;

          $DATA{$type}{$oid} = { %OBJ } ;

       }

       # [ ] process multiple addresses ?
       elsif ( $type eq ".com.infoblox.dns.host_address" ) {
          my $ihost = &invert_name ( $OBJ{'host'} ) ;
          $OBJ{'host'} = $ihost ;

          push @{ $DATA{$type}{$ihost} } , { %OBJ } ;

       }

       # [ ] sput zones
       elsif ( $type eq ".com.infoblox.dns.zone" ) {

          # join name to parent zone
          my $lname = "$OBJ{'zone'}.$OBJ{'name'}";
          debug ( $DEBUG , 3 , "lzone [$lname]" );

          # get a better fqdn
          my $izone = &invert_name ( $lname ) ;

          if ( $izone =~ /in-addr.arpa$/ ) {
             # re-name reverse zones
             my ( $net , $cidr ) = arpa_to_net ( $izone ) ;
             $izone = "$net/$cidr";
          }

          debug ( $DEBUG , 2 , "rzone [$izone]" );

          # rename
          $OBJ{'name'} = $izone ;

          $DATA{$type}{$oid} = { %OBJ } ;
       }
       # delegations etc etc
       elsif ( $type eq ".com.infoblox.dns.zone_delegated_server" ) {
          my $zone = &invert_name ( $OBJ{'zone'} ) ;
          $OBJ{'zone'} = $zone ;

          # shove in an array of delegations
          push @{ $DATA{$type}{$zone} } , { %OBJ } ;
       }

       # [ ] sput ranges
       elsif ( $type eq ".com.infoblox.dns.dhcp_range" ) {
          
          # get cidr netmask
          my ( $net , $mask ) = split ( /\//, $OBJ{'network'} ) ;
          my $cidr = masktocidr ( $mask ) ;

          $OBJ{'network'} = "$net/$cidr" ;

          # save it
          $DATA{$type}{$oid} = { %OBJ } ;

       }

       else {
          # do nothing
       }

       # dump the hash
       debug ( $DEBUG , 3 , Dumper( { %OBJ } ) );

       # clean the hash
       undef %OBJ ;
    }
}

sub invert_name {
    my ( $name ) = @_ ;

    my @rname = reverse( split (/\./, $name ) );
#     my $inverted = join(".", @rname ) || "." ;
    my $inverted = join(".", @rname ) ;
       $inverted =~ s/\.*$//;

    debug ( $DEBUG , 3 , "invert name [$name] -> [$inverted]");

    return ( $inverted )

}

# a few notes about the FLAT data structure.
# hosts are __type = .com.infoblox.dns.host
# the hosts adddresses are __type = .com.infoblox.dns.host_address

#   __type = .com.infoblox.dns.bind_a
#   __type = .com.infoblox.dns.bind_cname
#   __type = .com.infoblox.dns.bind_mx
#   __type = .com.infoblox.dns.bind_ns
#   __type = .com.infoblox.dns.bind_resource_record
#   __type = .com.infoblox.dns.bind_soa
#   __type = .com.infoblox.dns.bulk_host
#   __type = .com.infoblox.dns.cluster_dhcp_properties
#   __type = .com.infoblox.dns.cluster_dns_properties
#   __type = .com.infoblox.dns.dhcp_range
#   __type = .com.infoblox.dns.dhcp_range_domain_name_server
#   __type = .com.infoblox.dns.host
#   __type = .com.infoblox.dns.host_address
#   __type = .com.infoblox.dns.member_dhcp_properties
#   __type = .com.infoblox.dns.member_dns_properties
#   __type = .com.infoblox.dns.network
#   __type = .com.infoblox.dns.network_custom_option
#   __type = .com.infoblox.dns.network_domain_name_server
#   __type = .com.infoblox.dns.network_parent
#   __type = .com.infoblox.dns.network_router
#   __type = .com.infoblox.dns.shared_network_parent
#   __type = .com.infoblox.dns.zone
#   __type = .com.infoblox.dns.zone_delegated_server
#   __type = .com.infoblox.one.admin

#   __type = .com.infoblox.one.cluster
#   __type = .com.infoblox.one.cluster_install
#   __type = .com.infoblox.one.cluster_monitor
#   __type = .com.infoblox.one.cluster_resolver
#   __type = .com.infoblox.one.cluster_security
#   __type = .com.infoblox.one.cluster_time
#   __type = .com.infoblox.one.hier_rule
#   __type = .com.infoblox.one.monitor_entry
#   __type = .com.infoblox.one.physical_node
#   __type = .com.infoblox.one.product_license
#   __type = .com.infoblox.one.system_state
#   __type = .com.infoblox.one.virtual_node
