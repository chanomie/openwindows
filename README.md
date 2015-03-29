# Windows.Toggle

We all love fresh air, but not when it gets in the way of the hard work your HVAC 
system is doing.  `Windows.Toggle` watches the settings of your Nest Thermostate and
the local weather sends a Growl notification to let you know when you should be opening
and closing the windows.

# Set Up

You'll need to run the following command lines options after you first download to
setup the local settings.

1. Set the Nest Client Secret for the App.
```
./windowstoggle.pl setNestClientSecret [client-secret]
```

2. Set the Forecast API key
```
./windowstoggle.pl setForecastApiKey [forecast-api-key]
```

3. Set your Latitude and Longitude to be used by the Forecast API to figure out the 
   local outdoor weather.
```
./windowstoggle.pl setLatLong [lat,long]
```
    

# Other Commands

* Set the current Window State manually
```
./windowstoggle.pl setWindowState [opened/closed]
```
    
* Set the Nest Access Token if you want to skip the OAuth process.
```
./windowstoggle.pl setNestAccessToken [access-token]
```

