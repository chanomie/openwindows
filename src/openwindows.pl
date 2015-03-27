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
use String::Util qw(trim);
use URI;

=head1 SYNOPSIS
=cut

###
## Main function
###
sub main(@ARGV) {
  my $CONFIG = {};
  my $DATA;
  my $commandString = shift(@ARGV);
  my $userAgent = LWP::UserAgent->new();
  
  ## Initialize the Configuration File
  $DATA = initialize($CONFIG);
  
  if(defined($commandString)) {
    if($commandString eq "setNestClientSecret") {
      $DATA->{'NEST-CLIENT-SECRET'} = shift(@ARGV);
    } elsif ($commandString eq "setForecastApiKey") {
      $DATA->{'FORECAST-API-KEY'} = shift(@ARGV);
    } elsif ($commandString eq "setLatLong") {
      $DATA->{'LATITUDE-LONGITUDE'} = shift(@ARGV);
    } elsif ($commandString eq "setWindowState") {
      $DATA->{'WINDOW-STATE'} = shift(@ARGV);
      $DATA->{'WINDOW-STATE-UPDATED'} = time();
    }
    
    
  } else {
    validateConfigAndData($CONFIG, $DATA);
    my ($indoorTemperature, $hvacMode, $targetTemperatureLow, $targetTemperatureHigh) =
        getIndoorTemperatureAndTargetNest($CONFIG, $DATA, $userAgent);
        
    my $outdoorTemperature = getOutdoorTemperature($CONFIG, $DATA, $userAgent);
    
    print("indoorTemperature [$indoorTemperature], hvacMode [$hvacMode], "
        . "targetTemperatureLow [$targetTemperatureLow], "
        . "targetTemperatureHigh [$targetTemperatureHigh], "
        . "outdoorTemperature [$outdoorTemperature]\n");
    
    if($hvacMode eq "heat-cool") {
      ## Trying to keep in a range, so just check if outdoor is in the range.
      if($outdoorTemperature > $targetTemperatureLow && $outdoorTemperature < $targetTemperatureHigh) {
        setWindowState($CONFIG, $DATA, 'open');
      } else {
        setWindowState($CONFIG, $DATA, 'closed');
      }
    } else {
      confess("Not yet implemented dealing with hvac mode of: $hvacMode");
    }
  }
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
  $CONFIG->{'NEST-AUTHORIZE-URL'} = 'https://home.nest.com/login/oauth2?client_id='
    . $CONFIG->{'NEST-CLIENT-ID'}
    . '&state=STATE';
  $CONFIG->{'NEST-ACCESS-TOKEN-URL'} = 'https://api.home.nest.com/oauth2/access_token?client_id='
    . $CONFIG->{'NEST-CLIENT-ID'}
    . '&code=AUTHORIZATION_CODE&client_secret='
    . 'NEST-CLIENT-SECRET'
    . '&grant_type=authorization_code';
      
  $CONFIG->{'NEST-DATA-URL'} = 'https://developer-api.nest.com/';
  $CONFIG->{'FORECAST-IO-URL'} = "https://api.forecast.io/forecast/APIKEY/LATLONG?exclude=minutely,hourly,daily,alerts,flags";
    
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
  
  $CONFIG->{'NEST-ACCESS-TOKEN-URL'} =~ s/NEST-CLIENT-SECRET/$DATA->{'NEST-CLIENT-SECRET'}/;
  $CONFIG->{'FORECAST-IO-URL'} =~ s/APIKEY/$DATA->{'FORECAST-API-KEY'}/;
  $CONFIG->{'FORECAST-IO-URL'} =~ s/LATLONG/$DATA->{'LATITUDE-LONGITUDE'}/;

  return $DATA;   
}

sub validateConfigAndData($$) {
  my $CONFIG = shift;
  my $DATA =shift;
  my $validationErrors = [];

  ## Validate all the settings exists.
  if(!exists $DATA->{'NEST-CLIENT-SECRET'} || length(trim($DATA->{'NEST-CLIENT-SECRET'})) == 0) {
  	push($validationErrors, "Missing config for [NEST-CLIENT-SECRET]. Set with command setNestClientSecret.");
  }
  if(!exists $DATA->{'FORECAST-API-KEY'} || length(trim($DATA->{'FORECAST-API-KEY'})) == 0) {
  	push($validationErrors, "Missing config for [FORECAST-API-KEY]. Set with command setForecastApiKey.");
  }
  if(!exists $DATA->{'LATITUDE-LONGITUDE'} || length(trim($DATA->{'LATITUDE-LONGITUDE'})) == 0) {
  	push($validationErrors, "Missing config for [LATITUDE-LONGITUDE]. Set with command setLatLong.");
  }
  
  my $errorCount = scalar(@{$validationErrors});
  if($errorCount > 0) {
    for my $validationError (@$validationErrors){
      print(STDERR "$validationError\n");
    }
    confess("Missing required configuration.  Please set configuration.");
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

sub getIndoorTemperatureAndTargetNest($$$) {
  my $CONFIG = shift;
  my $DATA = shift;
  my $userAgent = shift;
  
  authenticateNest($CONFIG, $DATA, $userAgent);
  
  my $nestDataUrl = URI->new($CONFIG->{'NEST-DATA-URL'});
  $nestDataUrl->query_form(auth => $DATA->{'NEST-ACCESS-TOKEN'});
  
  my $response = $userAgent->get( 
    $nestDataUrl,
	'Accept'   => 'application/json'
  );
  
  if($response->code() == 200) {
    my $dataJson = decode_json( $response->decoded_content() );
    
    # Get the first thermostat.  If there are no thermostats or multiple just throw
    # and error for now.
    my @thermostatsNames = keys $dataJson->{"devices"}->{"thermostats"};
    my $thermostatCount = scalar(@thermostatsNames);
    
    if($thermostatCount == 1) {
      # Need to take three different modes into account.
      # 1. Cooling - should be colder than the indoor temperature
      # 2. Heating - should be hotter than the indoor temperature
      # 3. Range (heat-cool) - should be in between the desired range
      
      my $thermostatId = $thermostatsNames[0];
      my $indoorTemperature = $dataJson->{"devices"}->{"thermostats"}->{$thermostatId}->{"ambient_temperature_f"};
      my $hvacMode = $dataJson->{"devices"}->{"thermostats"}->{$thermostatId}->{"hvac_mode"};
      my $targetTemperatureLow = $dataJson->{"devices"}->{"thermostats"}->{$thermostatId}->{"target_temperature_low_f"};
      my $targetTemperatureHigh = $dataJson->{"devices"}->{"thermostats"}->{$thermostatId}->{"target_temperature_high_f"};
            
      return ($indoorTemperature, $hvacMode, $targetTemperatureLow, $targetTemperatureHigh);
    } else {
      confess("Only works with one thermostat.  Result is showing [" . $thermostatCount . "]");
    }    
  } else {
    confess("Failed to get data from Nest [" . $nestDataUrl . "] with response of:\n"
			. $response->as_string());
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
	if($response->code() == 200) {
	  my $dataJson = decode_json( $response->decoded_content() );
	  $DATA->{'NEST-ACCESS-TOKEN'} = $dataJson->{"access_token"};
	} else {
	  confess("Failed to get a valid oauth access token with response of:\n"
			. $response->as_string());
	}
  }
}

sub getOutdoorTemperature($$$) {
  my $CONFIG = shift;
  my $DATA = shift;
  my $userAgent = shift;
  my $forecastIoUrl = $CONFIG->{'FORECAST-IO-URL'};
  
  my $response = $userAgent->get( 
    $forecastIoUrl,
	'Accept'   => 'application/json'
  );
  
  if($response->code() == 200) {
    my $dataJson = decode_json( $response->decoded_content() );
    my $outdoorTemperature = $dataJson->{'currently'}->{'temperature'};

    return $outdoorTemperature;
  } else {
    confess("Failed to get a valid Forecast IO response:\n"
	    . $response->as_string());
  }
  
  ## https://api.forecast.io/forecast/058e5e4407119ab672a888370c36f6a4/38.6332990,-121.3346720
}

sub setWindowState($$$) {
  my $CONFIG = shift;
  my $DATA = shift;
  my $newWindowState = shift;
  my $existingWindowState = $DATA->{'WINDOW-STATE'};
  
  if(!exists $DATA->{'WINDOW-STATE'} || length(trim($DATA->{'WINDOW-STATE'})) == 0) {
    $DATA->{'WINDOW-STATE'} = 'closed';
    $DATA->{'WINDOW-STATE-UPDATED'} = time();
  }

  if($existingWindowState eq "opened" && $newWindowState ne "opened") {
    print("Close the windows\n");
    $DATA->{'WINDOW-STATE'} = 'closed';
    $DATA->{'WINDOW-STATE-UPDATED'} = time();
  } elsif($existingWindowState eq "closed" && $newWindowState ne "closed") {
    print("Open the windows\n");
    $DATA->{'WINDOW-STATE'} = 'opened';
    $DATA->{'WINDOW-STATE-UPDATED'} = time();
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