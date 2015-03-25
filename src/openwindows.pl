#!/usr/bin/perl

use strict;
use Browser::Open qw( open_browser );
use Carp; # carp is warn, confess is exception
use Config::JSON; # http://search.cpan.org/~rizen/Config-JSON-1.5202/lib/Config/JSON.pm
use Data::Dumper;
use File::HomeDir;
use Mac::PropertyList qw(parse_plist_fh create_from_hash);

###
## Main function
###
sub main(@ARGV) {
  my $CONFIG = {};
  my $DATA = {};
  
  ## Initialize the Configuration File
  initialize($CONFIG, $DATA);
  authenticateNest($CONFIG, $DATA);
  
  storeData($CONFIG, $DATA);
  
}

sub initialize($$) {
  my $CONFIG = shift;
  my $DATA = shift;

  ## Config is just setup in the file.
  $CONFIG->{'NEST-CLIENT-ID'} = '4ada2c61-9441-43aa-93cf-e497818dc5db';
  $CONFIG->{'NEST-CLIENT-SECRET'} = $ENV{'nestapikey'};
  $CONFIG->{'NEST-AUTHORIZE-URL'} = 'https://home.nest.com/login/oauth2?client_id='
    . $CONFIG->{'NEST-CLIENT-ID'}
    . '&state=STATE';
  
  $CONFIG->{'NEST-ACCESS-TOKEN-URL'} = 'https://api.home.nest.com/oauth2/access_token?client_id='
    . $CONFIG->{'NEST-CLIENT-ID'}
    . '&code=AUTHORIZATION_CODE&client_secret='
    . $CONFIG->{'NEST-CLIENT-SECRET'}
    . '&grant_type=authorization_code';
    
  if($^O eq "darwin") {
    $CONFIG->{'DATA-FILE-TYPE'} = 'plist';
    $CONFIG->{'DATA-FILE'} = File::HomeDir->my_home . '/Library/Preferences/net.chaosserver.OpenYourWindows.plist';
  } else {
    confess("Unknown OS [" . $^O . "], so don't know how to store the property files.");
  }

  ## Data is initialized from the file system.
  if ( -e $CONFIG->{'DATA-FILE'} ) {

  }
}

sub storeData($$) {
  my $CONFIG = shift;
  my $DATA = shift;

  if($CONFIG->{'DATA-FILE-TYPE'} eq "plist") {
    my $plist = create_from_hash($DATA);
    open(my $fh, '>', $CONFIG->{'DATA-FILE'});
    print($fh $plist);
    close($fh);
  } else {
    confess("Unknown data file type [" . $CONFIG->{'DATA-FILE-TYPE'} . "]");
  }
}

sub authenticateNest($$) {
  my $CONFIG = shift;
  my $DATA = shift;

  # If the Nest Access Token Doesn't Exist do OAuth
  if(!exists $DATA->{'NEST-ACCESS-TOKEN'}) {
    my $ok = open_browser($CONFIG->{'NEST-AUTHORIZE-URL'});
  }
}

###
## Get Temperature Function to Get the Tempurature of the House
## 1. Nest Thermostat
## 2. Netatmo Weather
###

eval {
  main(@ARGV);
};
if ($@) {
  die $@;
};