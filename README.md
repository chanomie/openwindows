# NAME

Windows.Toggle a module to notify when you should open/close your windows.

# SYNOPSIS

We all love fresh air, but not when it gets in the way of the hard work your HVAC 
system is doing.  \`Windows.Toggle\` watches the settings of your Nest Thermostate and
the local weather sends a Growl notification to let you know when you should be opening
and closing the windows.

    Usage: WindowsToggle [command]
    

## SETUP

You'll need to run the following command lines options after you first download to
setup the local settings.

- Set the Nest Client Secret for the App.

        ./windowstoggle.pl setNestClientSecret [client-secret]

- Set the Forecast API key

        ./windowstoggle.pl setForecastApiKey [forecast-api-key]

- Set your Latitude and Longitude to be used by the Forecast API to figure out the 
      local outdoor weather.

        ./windowstoggle.pl setLatLong [lat,long]

## Other Commands

- Set the current Window State manually

        ./windowstoggle.pl setWindowState [opened/closed]
          

- Set the Nest Access Token if you want to skip the OAuth process.

        ./windowstoggle.pl setNestAccessToken [access-token]
        

# METHODS

## `main(@ARGV)`

- Input:
    - @ARGV

        typically the argument list from the command line

The main function checks for a specific run command and if none is provided will run
a standard loop.

## `initialize(\%CONFIG)`

- Input:
    - \\%CONFIG

        the configuration hashref.  Configuration settings that are hard coded
        into the setup method.
- Output:
    - \\%DATA

        the data hashref. Data is configuration that is stored in a local data
        file.  The location and format of the file is environment dependent.

Initialize the environment by loading $CONFIG and $DATA.

## `displayHelp()`

Display help to the system out.  Primarily used to display the various commands
that can be run.

## `initialize(\%CONFIG, \%DATA)`

- Input:
    - \\%CONFIG
    the configuration hashref.  Configuration settings that are hard coded
    into the setup method.
    - \\%DATA
    the data hashref. Data is configuration that is stored in a local data
    file.  The location and format of the file is environment dependent.
- Throws:
    - Confesses if there is an missing data in settings that is required for standard
          operations

Validates the configuration and data to ensure that all settings are properly
configured.

## loadData($CONFIG)
Input:
  \\%CONFIG = the configuration hashref.  Configuration settings that are hard coded
             into the setup method.

Output:
  \\%DATA = the data hashref. Data is configuration that is stored in a local data
           file.  The location and format of the file is environment dependent.

Loads the data from the local store.

## loadData($CONFIG, $DATA)
Input:
  \\%CONFIG = the configuration hashref.  Configuration settings that are hard coded
             into the setup method.
  \\%DATA = the data hashref. Data is configuration that is stored in a local data
           file.  The location and format of the file is environment dependent.

Output: None

Stores the values of $DATA into a local file.  The location and format of the file is
environment dependent.

## getIndoorTemperatureAndTargetNest($CONFIG, $DATA, $userAgent)
Input:
  \\%CONFIG   = the configuration hashref.  Configuration settings that are hard coded
               into the setup method.
  \\%DATA     = the data hashref. Data is configuration that is stored in a local data
               file.  The location and format of the file is environment dependent.
  $userAgent = A LWP::UserAgent object used to make REST API calls to Nest

Output:
  $indoorTemperature      = the current indoor temperature
  $hvacMode               = hvac mode can be heat, cool, heat-cool
  $targetTemperatureLow   = the target low temperature for cool or heat-cool
  $targetTemperatureHigh  = the target high temperature for heat or heat-cool

Makes and API call to the Nest API to get back the current settings from the thermostat.
