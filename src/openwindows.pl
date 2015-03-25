#!/usr/bin/perl

use strict;
use Browser::Open qw( open_browser );
use Carp; # carp is warn, confess is exception
use Config::JSON; # http://search.cpan.org/~rizen/Config-JSON-1.5202/lib/Config/JSON.pm
use Data::Dumper;
use File::HomeDir;
use JSON;
use Mac::PropertyList qw(parse_plist_fh create_from_hash);
use LWP::UserAgent;

=head1 SYNOPSIS
=cut

###
## Main function
###
sub main(@ARGV) {
  my $CONFIG = {};
  my $DATA;
  my $userAgent = LWP::UserAgent->new();

  ## Initialize the Configuration File
  $DATA = initialize($CONFIG);
  authenticateNest($CONFIG, $DATA, $userAgent);
  
  storeData($CONFIG, $DATA);
  
}

=head2 initialize
* $CONFIG = the configuration hashref
* returns $DATA = the data hashref
 
Initialize the environment by loading $CONFIG and $DATA.

$CONFIG is configuration settings that are hard coded into the setup method.
$DATA is configuration that is stored in a local data file.  The location and format of
  the file is environment dependent.
=cut

sub initialize($) {
  my $CONFIG = shift;
  my $DATA;

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
    $DATA = loadData($CONFIG, $DATA);
  } else {
    $DATA = {};
  }
}

=head2 loadData
* $CONFIG = the configuration hashref
* returns $DATA = the data hashref

Loads the values of $DATA into a local file.  The location and format of the file is
environment dependent.
=cut
sub loadData($) {
  my $CONFIG = shift;

  if($CONFIG->{'DATA-FILE-TYPE'} eq "plist") {
    open(my $fh, '<', $CONFIG->{'DATA-FILE'});
    my $plist = parse_plist_fh($fh);
    close($fh);
    
    return $plist->as_perl();
  } else {
    confess("Unknown data file type [" . $CONFIG->{'DATA-FILE-TYPE'} . "]");
  }
}


=head2 storeData
* $CONFIG = the configuration hashref
* $DATA = the data hashref

Stores the values of $DATA into a local file.  The location and format of the file is
environment dependent.
=cut
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

sub authenticateNest($$$) {
  my $CONFIG = shift;
  my $DATA = shift;
  my $userAgent = shift;

  # If the Nest Access Token Doesn't Exist do OAuth
  
  # OAuth Step #1 is to go the Authorize URL.  Using in oob (out-of-band) mode
  # requires the user to get an authorization code.
  if(!exists $DATA->{'NEST-ACCESS-TOKEN'}) {
    my $openBrowserReply = open_browser($CONFIG->{'NEST-AUTHORIZE-URL'}); 
    my $accessTokenUrl = $CONFIG->{'NEST-ACCESS-TOKEN-URL'};
    
    if (! defined($openBrowserReply) ) {
      print("Not able to open the browser, please direct your web browser to the following URL:\n");
      print($CONFIG->{'NEST-AUTHORIZE-URL'} . "\n");
      print("\n");
    }

    print("Enter the authorization code provide by nest: ");
    chomp(my $authorizationCode = <>);

    undef $openBrowserReply;
    $accessTokenUrl =~ s/AUTHORIZATION_CODE/$authorizationCode/;

	my $response = $userAgent->post($accessTokenUrl);
    my $httpResponseCode = $response->code();
	if($httpResponseCode == 200) {
	  my $dataJson = decode_json( $response->decoded_content() );
	  $DATA->{'NEST-ACCESS-TOKEN'} = $dataJson->{"access_token"};
	} else {
	  confess("Failed to get a valid oauth access token with response of:\n"
			. $response->as_string());
	}
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