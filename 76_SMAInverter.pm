###############################################################
# 
#
#  Copyright notice
#
#  Published according Creative Commons : Attribution-NonCommercial-ShareAlike 3.0 Unported (CC BY-NC-SA 3.0)
#  Details: https://creativecommons.org/licenses/by-nc-sa/3.0/
#
#  Credits:
#  - based on 77_SMASTP.pm by Volker Kettenbach with following credits:
#    - based on an Idea by SpenZerX and HDO
#    - Waldmensch for various improvements
#    - sbfspot (https://sbfspot.codeplex.com/)
#  - written by Thomas Schoedl (sct14675) with inputs from Volker, waldmensch and DS_starter
# 
#  Description:
#  This is an FHEM-Module for SMA Inverters.
#  Tested on Sunny Tripower 6000TL-20 and Sunny Island 4.4
#
#  Requirements:
#  This module requires:
#  - Perl Module: IO::Socket::INET
#  - Perl Module: Datime
#
#
###############################################################

package main;

use strict;
use warnings;
use IO::Socket::INET;      
use DateTime;

# Global vars
my $globname = "SMAInverter";

# Sleep Mode variables
my $default_starthour = "05:00";
my $starthour = 5;
my $startminute = 0;
my $default_endhour = "22:00";
my $endhour = 22;
my $endminute = 0;
my $suppress_night_mode = 0;
# Reporting (=Reading) detail level: 
# 0 - Standard (only power and energy), 1 - More details(including current and voltage), 2 - All Data
my $detail_level = 0;
# General enabling of the module
my $modulstate_enabled = 0;
# protocol related
my $mysusyid = 233;								# random number, has to be different from any device in local network
my $myserialnumber = 123321123;		# random number, has to be different from any device in local network
my $target_susyid = 0xFFFF;				# 0xFFFF is any susyid
my $target_serial = 0xFFFFFFFF;		# 0xFFFFFFFF is any serialnumber
my $default_target_susyid = 0xFFFF;				# 0xFFFF is any susyid
my $default_target_serial = 0xFFFFFFFF;		# 0xFFFFFFFF is any serialnumber
my $pkt_ID = 0x8001;						# Packet ID

#Return values
my $r_OK = 0;		# Everything OK
my $r_FAIL = 1;	# Operation failed
my $r_SLEEP = 2;# Sleep mode

# Inverter Data fields and supported commands flags. "1" means not supported (= $r_FAIL)
my $inv_susyid = 0;
my $inv_serial = 0;
my $inv_SPOT_ETODAY = 0;						# Today yield
my $inv_SPOT_ETOTAL = 0;						# Total yield
my $sup_EnergyProduction = $r_FAIL;	# EnergyProduction command supported
my $inv_SPOT_PDC1 = 0;							# DC power input 1
my $inv_SPOT_PDC2 = 0;							# DC power input 2
my $sup_SpotDCPower = $r_FAIL;			# SpotDCPower command supported
my $inv_SPOT_PAC1 = 0;							# Power L1 
my $inv_SPOT_PAC2 = 0;							# Power L2 
my $inv_SPOT_PAC3 = 0;							# Power L3 
my $sup_SpotACPower = $r_FAIL;			# SpotACPower command supported
my $inv_PACMAX1 = 0;								# Nominal power in Ok Mode
my $inv_PACMAX2 = 0;								# Nominal power in Warning Mode
my $inv_PACMAX3 = 0;								# Nominal power in Fault Mode
my $sup_MaxACPower = $r_FAIL;				# MaxACPower command suported
my $inv_PACMAX1_2 = 0;							# Maximum active power device (Some inverters like SB3300/SB1200)
my $sup_MaxACPower2 = $r_FAIL;			# MaxACPower2 command suported
my $inv_SPOT_PACTOT = 0;						# Total Power
my $sup_SpotACTotalPower = $r_FAIL; # SpotACTotalPower command supported
my $inv_ChargeStatus = 0;						# Battery Charge status
my $sup_ChargeStatus = $r_FAIL;			# BatteryChargeStatus command supported
my $inv_SPOT_UDC1 = 0;							# DC voltage input
my $inv_SPOT_UDC2 = 0;							# DC voltage input
my $inv_SPOT_IDC1 = 0;							# DC current input
my $inv_SPOT_IDC2 = 0;							# DC current input
my $sup_SpotDCVoltage = $r_FAIL;		# SpotDCVoltage command supported
my $inv_SPOT_UAC1 = 0;							# Grid voltage phase L1
my $inv_SPOT_UAC2 = 0;							# Grid voltage phase L2
my $inv_SPOT_UAC3 = 0;							# Grid voltage phase L3
my $inv_SPOT_IAC1 = 0;							# Grid current phase L1
my $inv_SPOT_IAC2 = 0;							# Grid current phase L2
my $inv_SPOT_IAC3 = 0;							# Grid current phase L3
my $sup_SpotACVoltage = $r_FAIL;		# SpotACVoltage command supported
my $inv_BAT_UDC = 0;								# Battery Voltage
my $inv_BAT_IDC = 0;								# Battery Current
my $inv_BAT_CYCLES = 0;							# Battery recharge cycles
my $inv_BAT_TEMP = 0;								# Battery temperature
my $sup_BatteryInfo = $r_FAIL;			# BatteryInfo command supported
my $inv_SPOT_FREQ = 0;							# Grid Frequency
my $sup_SpotGridFrequency = $r_FAIL;# SpotGridFrequency command supported
my $inv_CLASS = 0;									# Inverter Class
my $inv_TYPE = 0;										# Inverter Type
my $sup_TypeLabel = $r_FAIL;				# TypeLabel command supported
my $inv_SPOT_OPERTM = 0;						# Operation Time
my $inv_SPOT_FEEDTM = 0;						# Feed-in time
my $sup_OperationTime = $r_FAIL;		# OperationTime command supported
my $inv_TEMP = 0;										# Inverter temperature
my $sup_InverterTemperature = $r_FAIL; # InverterTemperature command supported

###################################
sub SMAInverter_Initialize($)
{
	my ($hash) = @_;
	my $name = $hash->{NAME};
	my $hval;
	my $mval;

	$hash->{DefFn}     = "SMAInverter_Define";
	$hash->{UndefFn}   = "SMAInverter_Undef";
	$hash->{AttrList}  = "suppress-night-mode:0,1 " .
						"starttime " .
						"endtime " .
						"enable-modulstate:0,1 " .
						"interval " . 
						"detail-level:0,1,2 " .
						"target-susyid " .
						"target-serial " .
						$readingFnAttributes;
	$hash->{AttrFn}   = "SMAInverter_Attr";
	
	if ($attr{$name}{"starttime"})
	{
		($hval, $mval) = split(/:/,$attr{$name}{"starttime"});
	}
	else
	{
		($hval, $mval) = split(/:/,$default_starthour);
	}
	$starthour = int($hval);
	$startminute = int($mval);
	
	if ($attr{$name}{"endtime"})
	{
		($hval, $mval) = split(/:/,$attr{$name}{"endtime"});
	}
	else
	{
		($hval, $mval) = split(/:/,$default_endhour);
	}
	$endhour = int($hval);
	$endminute = int($mval);

	$suppress_night_mode = ($attr{$name}{"suppress-night-mode"}) ? $attr{$name}{"suppress-night-mode"} : 0;
	$modulstate_enabled = ($attr{$name}{"enable-modulstate"}) ? $attr{$name}{"enable-modulstate"} : 0;
	$detail_level = ($attr{$name}{"detail-level"}) ? $attr{$name}{"detail-level"} : 0;
	$target_susyid = ($attr{$name}{"target-susyid"}) ? $attr{$name}{"target-susyid"} : $default_target_susyid;
	$target_serial = ($attr{$name}{"target-serial"}) ? $attr{$name}{"target-serial"} : $default_target_serial;
	
	Log3 $name, 0, "$name: Started with sleepmode from $endhour:$endminute - $starthour:$startminute";
}

###################################
sub is_Sleepmode()
{
	# Build 3 DateTime Objects to make the comparison more robust
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
	my $dt_startdate = DateTime->new(year=>$year+1900,month=>$mon+1,day=>$mday,hour=>$starthour,minute=>$startminute,second=>0,time_zone=>'local');
	my $dt_enddate = DateTime->new(year=>$year+1900,month=>$mon+1,day=>$mday,hour=>$endhour,minute=>$endminute,second=>0,time_zone=>'local');
	my $dt_now = DateTime->now(time_zone=>'local');

	# Return of any value != 0 means "sleeping"
	if ($dt_now >= $dt_enddate || $dt_now <= $dt_startdate)
	{
		# we have reached normal sleepmode now
		return $r_SLEEP;
	}
	else
	{
		# no sleepmode
		return $r_OK;
	}
}

###################################
sub SMAInverter_Define($$)
{
	my ($hash, $def) = @_;
	my @a = split("[ \t][ \t]*", $def);

	return "Wrong syntax: use define <name> SMAInverter <inv-userpwd> <inv-hostname/inv-ip > " if ((int(@a) < 4) and (int(@a) > 5));

	my $name	= $a[0];
	$hash->{NAME} 	= $name;
	$hash->{LASTUPDATE}=0;
	$hash->{INTERVAL} = 60;

	# SMAInverter	= $a[1];
	my ($IP,$Host,$Caps);

	my $Pass = $a[2];		# to do: check 1-12 Chars

	# extract IP or Hostname from $a[4]
	if ( $a[3] ~~ m/^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/ )
	{
	if ( $1 <= 255 && $2 <= 255 && $3 <= 255 && $4 <= 255 )
		{
			$Host = int($1).".".int($2).".".int($3).".".int($4);
		}
	}
	
	if (!defined $Host)
	{
		if ( $a[3] =~ /^([A-Za-z0-9_.])/ )
		{
			$Host = $a[3];
		}
	}
	
	if (!defined $Host)
	{
		return "Argument:{$a[3]} not accepted as Host or IP. Read device specific help file.";
	}

	$hash->{Pass} = $Pass; 
	$hash->{Host} = $Host;

	InternalTimer(gettimeofday()+5, "SMAInverter_GetStatus", $hash, 0);	# refresh timer start

	return undef;
}

#####################################
sub SMAInverter_Undef($$)
{
	my ($hash, $name) = @_;
	RemoveInternalTimer($hash); 
	Log3 $hash, 0, "$name: Undefined!";
	return undef;
}

###################################
sub SMAInverter_Attr(@)
{
	my ($cmd,$name,$aName,$aVal) = @_;
  	# $cmd can be "del" or "set"
	# $name is device name
	# aName and aVal are Attribute name and value
	my $hash = $defs{$name};
	
	my $hval;
	my $mval;

	if (($aName eq "starttime" || $aName eq "endtime") && not ($aVal =~ /^([0-1]?[0-9]|[2][0-3]):([0-5][0-9])$/))
	{
		return "value $aVal invalid"; # no correct time format hh:mm
	}
	
	if ($aName eq "enable-modulstate")
	{
		$modulstate_enabled  = ($cmd eq "set") ?  int($aVal) : 0;
		Log3 $name, 3, "$name: Set $aName to $aVal";
	}
	
	if ($aName eq "starttime")
	{
		if ($cmd eq "set")
		{
			($hval, $mval) = split(/:/,$aVal);
		}
		else
		{
			($hval, $mval) = split(/:/,$default_starthour);
		}
		if (int($hval) < 12)
		{
			$starthour = int($hval);
			$startminute = int($mval);
		}
		else
		{
			return "$name: Attr starttime must be set smaller than 12:00! Not set to $starthour:$startminute";
		}
		
		Log3 $name, 3, "$name: Attr starttime is set to " . sprintf("%02d:%02d",$starthour,$startminute);
	}
	
	if ($aName eq "endtime")
	{
		if ($cmd eq "set")
		{
			($hval, $mval) = split(/:/,$aVal);
		}
		else
		{
			($hval, $mval) = split(/:/,$default_endhour);
		}
		
		if (int($hval) > 12)
		{
			$endhour = int($hval);
			$endminute = int($mval);
		}
		else
		{
			return "$name: Attr endtime must be set larger than 12:00! Not set to $endhour:$endminute";
		}
		
		Log3 $name, 3, "$name: Attr endtime is set to " . sprintf("%02d:%02d",$endhour,$endminute);
	}
	
	if ($aName eq "suppress-night-mode") 
	{
		$suppress_night_mode = ($cmd eq "set") ? $aVal : 0;
		Log3 $name, 3, "$name: Set $aName to $aVal";
	}

	if ($aName eq "target-susyid") 
	{
		$target_susyid = ($cmd eq "set") ? $aVal : $default_target_susyid;
		Log3 $name, 3, "$name: Set $aName to $aVal";
	}

	if ($aName eq "target-serial") 
	{
		$target_serial = ($cmd eq "set") ? $aVal : $default_target_serial;
		Log3 $name, 3, "$name: Set $aName to $aVal";
	}
		
	if ($aName eq "detail-level") 
	{
		$detail_level = ($cmd eq "set") ? $aVal : 0;
		Log3 $name, 3, "$name: Set $aName to $aVal";
	}
		
	if ($aName eq "interval") 
	{
		if ($cmd eq "set") 
		{
			$hash->{INTERVAL} = $aVal;
			Log3 $name, 3, "$name: Set $aName to $aVal";
		}
	} else 
	{
		$hash->{INTERVAL} = "60";
		Log3 $name, 3, "$name: Set $aName to $aVal";
	}
	return undef;
}

#####################################
sub SMAInverter_GetStatus($)
{
	my ($hash) = @_;
	my $name = $hash->{NAME};
	my $interval = $hash->{INTERVAL};
	
	# Get the current attributes
	$detail_level = ($attr{$name}{"detail-level"}) ? $attr{$name}{"detail-level"} : 0;
	$target_susyid = ($attr{$name}{"target-susyid"}) ? $attr{$name}{"target-susyid"} : $default_target_susyid;
	$target_serial = ($attr{$name}{"target-serial"}) ? $attr{$name}{"target-serial"} : $default_target_serial;
	$suppress_night_mode = ($attr{$name}{"suppress-night-mode"}) ? $attr{$name}{"suppress-night-mode"} : 0;
		
	# For logging events set the module name
	$globname = $name;
	
	if(($suppress_night_mode eq 1) || (is_Sleepmode() eq $r_OK))
	{
		if(SMA_logon($hash->{Host}, $hash->{Pass}) eq $r_OK)
		{
				Log3 $globname, 5, "$globname: Logged in now";

					
				# Check TypeLabel
				$sup_TypeLabel = SMA_command($hash->{Host}, 0x58000200, 0x00821E00, 0x008220FF);
									
				# Check EnergyProduction
				$sup_EnergyProduction = SMA_command($hash->{Host}, 0x54000200, 0x00260100, 0x002622FF);
				
				# Check SpotDCPower
				$sup_SpotDCPower = SMA_command($hash->{Host}, 0x53800200, 0x00251E00, 0x00251EFF);
				
				# Check SpotACPower
				$sup_SpotACPower = SMA_command($hash->{Host}, 0x51000200, 0x00464000, 0x004642FF);

				# Check MaxACPower
				$sup_MaxACPower = SMA_command($hash->{Host}, 0x51000200, 0x00411E00, 0x004120FF);

				# Check MaxACPower2
				$sup_MaxACPower2 = SMA_command($hash->{Host}, 0x51000200, 0x00832A00, 0x00832AFF);

				# Check SpotACTotalPower
				$sup_SpotACTotalPower = SMA_command($hash->{Host}, 0x51000200, 0x00263F00, 0x00263FFF);
		
				# Check BatteryChargeStatus
				$sup_ChargeStatus = SMA_command($hash->{Host}, 0x51000200, 0x00295A00, 0x00295AFF);
				
				if($detail_level > 0) {
					# Detail Level 1 or 2 >> get voltage and current levels
					# Check SpotDCVoltage
					$sup_SpotDCVoltage = SMA_command($hash->{Host}, 0x53800200, 0x00451F00, 0x004521FF);
					
					# Check SpotACVoltage
					$sup_SpotACVoltage = SMA_command($hash->{Host}, 0x51000200, 0x00464800, 0x004655FF);
					
					# Check BatteryInfo
					$sup_BatteryInfo = SMA_command($hash->{Host}, 0x51000200, 0x00491E00, 0x00495DFF);
				}

				if($detail_level > 1) {
					# Detail Level 2 >> get all data
					# Check SpotGridFrequency
					$sup_SpotGridFrequency = SMA_command($hash->{Host}, 0x51000200, 0x00465700, 0x004657FF);

					# Check OperationTime
					$sup_OperationTime = SMA_command($hash->{Host}, 0x54000200, 0x00462E00, 0x00462FFF);

					# Check InverterTemperature
					$sup_InverterTemperature = SMA_command($hash->{Host}, 0x52000200, 0x00237700, 0x002377FF);
				}

				# nothing more to do, just log out
				SMA_logout($hash->{Host});

				# Update Readings
				readingsBeginUpdate($hash);
				readingsBulkUpdate($hash, "modulstate", "normal");
				if($sup_EnergyProduction eq $r_OK) {
					readingsBulkUpdate($hash, "SPOT_ETOTAL", $inv_SPOT_ETOTAL);
					readingsBulkUpdate($hash, "SPOT_ETODAY", $inv_SPOT_ETODAY);					
				}
				if($sup_SpotDCPower eq $r_OK) {
					readingsBulkUpdate($hash, "SPOT_PDC1", $inv_SPOT_PDC1);
					readingsBulkUpdate($hash, "SPOT_PDC2", $inv_SPOT_PDC2);					
				}				
				if($sup_SpotACPower eq $r_OK) {
					readingsBulkUpdate($hash, "SPOT_PAC1", $inv_SPOT_PAC1);
					readingsBulkUpdate($hash, "SPOT_PAC2", $inv_SPOT_PAC2);					
					readingsBulkUpdate($hash, "SPOT_PAC3", $inv_SPOT_PAC3);					
				}				
				if($sup_MaxACPower eq $r_OK) {
					readingsBulkUpdate($hash, "INV_PACMAX1", $inv_PACMAX1);
					readingsBulkUpdate($hash, "INV_PACMAX2", $inv_PACMAX2);					
					readingsBulkUpdate($hash, "INV_PACMAX3", $inv_PACMAX3);					
				}				
				if($sup_MaxACPower2 eq $r_OK) {
					readingsBulkUpdate($hash, "INV_PACMAX1_2", $inv_PACMAX1_2);					
				}				
				if($sup_SpotACTotalPower eq $r_OK) {
					readingsBulkUpdate($hash, "SPOT_PACTOT", $inv_SPOT_PACTOT);
					readingsBulkUpdate($hash, "state", $inv_SPOT_PACTOT);							
				}
				if($sup_ChargeStatus eq $r_OK) {
					readingsBulkUpdate($hash, "ChargeStatus", $inv_ChargeStatus);			
				}
				if($inv_CLASS eq 8007) {
					if($inv_SPOT_PACTOT < 0) {
						readingsBulkUpdate($hash, "POWER_OUT", 0);
						readingsBulkUpdate($hash, "POWER_IN", -1 * $inv_SPOT_PACTOT);
					} else {
						readingsBulkUpdate($hash, "POWER_OUT", $inv_SPOT_PACTOT);
						readingsBulkUpdate($hash, "POWER_IN", 0);
					}
				}

				if($detail_level > 0) {
					# For Detail Level 1 and 2
					
					if($sup_SpotDCVoltage eq $r_OK) {
						readingsBulkUpdate($hash, "SPOT_UDC1", $inv_SPOT_UDC1);
						readingsBulkUpdate($hash, "SPOT_UDC2", $inv_SPOT_UDC2);
						readingsBulkUpdate($hash, "SPOT_IDC1", $inv_SPOT_IDC1);
						readingsBulkUpdate($hash, "SPOT_IDC2", $inv_SPOT_IDC2);
					}
					
					if($sup_SpotACVoltage eq $r_OK) {
						readingsBulkUpdate($hash, "SPOT_UAC1", $inv_SPOT_UAC1);
						readingsBulkUpdate($hash, "SPOT_UAC2", $inv_SPOT_UAC2);
						readingsBulkUpdate($hash, "SPOT_UAC3", $inv_SPOT_UAC3);
						readingsBulkUpdate($hash, "SPOT_IAC1", $inv_SPOT_IAC1);
						readingsBulkUpdate($hash, "SPOT_IAC2", $inv_SPOT_IAC2);
						readingsBulkUpdate($hash, "SPOT_IAC3", $inv_SPOT_IAC3);
					}
					
					if($sup_BatteryInfo eq $r_OK) {
						readingsBulkUpdate($hash, "BAT_UDC", $inv_BAT_UDC);
						readingsBulkUpdate($hash, "BAT_IDC", $inv_BAT_IDC);
					}
				}	
				
				if($detail_level > 1) {
					# For Detail Level 2
					readingsBulkUpdate($hash, "SUSyID", $inv_susyid);
					readingsBulkUpdate($hash, "Serialnumber", $inv_serial);
					
					if($sup_BatteryInfo eq $r_OK) {
						readingsBulkUpdate($hash, "BAT_CYCLES", $inv_BAT_CYCLES);
						readingsBulkUpdate($hash, "BAT_TEMP", $inv_BAT_TEMP);
					}
					
					if($sup_SpotGridFrequency eq $r_OK) {
						readingsBulkUpdate($hash, "SPOT_FREQ", $inv_SPOT_FREQ);
					}
					
					if($sup_TypeLabel eq $r_OK) {
						readingsBulkUpdate($hash, "INV_TYPE", $inv_TYPE);
						if ($inv_CLASS eq 8001) {
							readingsBulkUpdate($hash, "INV_CLASS", "Solar Inverter");
						} 
						elsif ($inv_CLASS eq 8007) {
							readingsBulkUpdate($hash, "INV_CLASS", "Battery Inverter");
						} 
						else {
							readingsBulkUpdate($hash, "INV_CLASS", $inv_CLASS);
						}
					}
					
					if($sup_InverterTemperature eq $r_OK) {
						readingsBulkUpdate($hash, "INV_TEMP", $inv_TEMP);
					}
					
					if($sup_OperationTime eq $r_OK) {
						readingsBulkUpdate($hash, "SPOT_FEEDTM", $inv_SPOT_FEEDTM);
						readingsBulkUpdate($hash, "SPOT_OPERTM", $inv_SPOT_OPERTM);
					}
				}
													
				readingsEndUpdate($hash, 1);	# Notify is done by Dispatch
		} else
		{
				# Login failed/not possible
				readingsBeginUpdate($hash);
				readingsBulkUpdate($hash, "state", "Login failed");
				readingsBulkUpdate($hash, "modulstate", "login failed");
				readingsEndUpdate($hash, 1);	# Notify is done by Dispatch		
		}
	} else
	{
		# Sleep Mode activated
				# Login failed/not possible
				readingsBeginUpdate($hash);
				readingsBulkUpdate($hash, "state", "sleep");
				readingsBulkUpdate($hash, "modulstate", "sleepmode active");
				readingsEndUpdate($hash, 1);	# Notify is done by Dispatch	
	}
	
	InternalTimer(gettimeofday()+$interval, "SMAInverter_GetStatus", $hash, 1);
}

####################################
sub SMA_logon($$)
{
	# Parameters: host - passcode
	my $host = $_[0];
	my $pass = $_[1];
	my $cmdheader = "534D4100000402A00000000100";
	my $pktlength = "3A";		# length = 58 for logon command
	my $esignature = "001060650EA0";
	my $cmd = "";
	my $timestmp = "";
	my $myID = "";
	my $target_ID = "";
	my $spkt_ID = "";
	my $cmd_ID = "";
	my ($socket,$data,$size);
	
	use constant MAXBYTES => scalar 100;
	
	#Encode the password
	my $encpasswd = "888888888888888888888888"; # template for password	
	for my $index (0..length $pass )	# encode password
	{
		substr($encpasswd,($index*2),2) = substr(sprintf ("%lX", (hex(substr($encpasswd,($index*2),2)) + ord(substr($pass,$index,1)))),0,2);
	}
	
	# Get current timestamp in epoch format (unix format)
	$timestmp = ByteOrderLong(sprintf("%08X",int(time())));
	
	# Define own ID and target ID and packet ID
	$myID = ByteOrderShort(substr(sprintf("%04X",$mysusyid),0,4)) . ByteOrderLong(sprintf("%08X",$myserialnumber));
	$target_ID = ByteOrderShort(substr(sprintf("%04X",$target_susyid),0,4)) . ByteOrderLong(sprintf("%08X",$target_serial));
	$pkt_ID = 0x8001;	# Reset to 0x8001
	$spkt_ID = ByteOrderShort(sprintf("%04X",$pkt_ID));
	
	#Logon command
	$cmd_ID = "0C04FDFF" . "07000000" . "84030000";  # Logon command + User group "User" + (maybe) Timeout
	
	#build final command to send
	$cmd = $cmdheader . $pktlength . $esignature . $target_ID . "0001" . $myID . "0001" . "00000000" . $spkt_ID . $cmd_ID . $timestmp . "00000000" . $encpasswd . "00000000";

	# flush after every write
	$| = 1; 				
	
	# Create Socket and check if successful
	$socket = new IO::Socket::INET (PeerHost => $host, PeerPort => 9522, Proto => 'udp',); # open Socket

	if (!$socket) { 															
		# in case of error
		Log3 $globname, 1, "$globname: ERROR. Can't open socket to inverter: $!";
		return $r_FAIL;
	};

	# Send Data
	$data = pack("H*",$cmd);
	$socket->send($data);
	Log3 $globname, 4, "$globname: Send login to $host on Port 9522 with password $pass ";
	Log3 $globname, 5, "$globname: Send: $cmd ";
	
	# Receive Data and do a first check regarding length
	eval 
	{
		local $SIG{ALRM} = sub { die "alarm time out" };
		alarm 5;
		# receive data
		$socket->recv($data, MAXBYTES) or die "recv: $!";					
		$size = length($data);

		# check if something was received
		if (defined $size)															
		{
			my $received = unpack("H*", $data);
			Log3 $globname, 5, "$globname: Received: $received";
			
		}
		
		alarm 0;
		1;																	
	} or Log3 $globname, 1, "$globname query timed out";
	
	# Nothing received -> exit
	if (not defined $size)															
	{
		Log3 $globname, 1, "$globname: Nothing received...";
		# send: cmd_logout
		$socket->close();
		SMA_logout($host);
		return $r_FAIL;
	} else
	{
		# We have received something!
		
		if ($size > 62)
		{
			# Check all parameters of answer
			my $r_susyid = unpack("v*", substr $data, 20, 2);
			my $r_serial = unpack("V*", substr $data, 22, 4);
			my $r_pkt_ID = unpack("v*", substr $data, 40, 2);
			my $r_cmd_ID = unpack("V*", substr $data, 42, 4);
			my $r_error  = unpack("V*", substr $data, 36, 4);
			if (($r_susyid ne $mysusyid) || ($r_serial ne $myserialnumber) || ($r_pkt_ID ne $pkt_ID) || ($r_cmd_ID ne 0xFFFD040D) || ($r_error ne 0))
			{
				# Response does not match the parameters we have sent, maybe different target
				Log3 $globname, 1, "$globname: Inverter answer does not match our parameters.";
				Log3 $globname, 5, "$globname: Request/Response: SusyID $mysusyid/$r_susyid, Serial $myserialnumber/$r_serial, Packet ID $pkt_ID/$r_pkt_ID, Command 0xFFFD040D/$r_cmd_ID, Error $r_error";
				# send: cmd_logout
				$socket->close();
				SMA_logout($host);
				return $r_FAIL;
			}
			# ******************************************************************
			
		} else
		{
			Log3 $globname, 1, "$globname: Format of inverter response does not fit.";
			# send: cmd_logout
			$socket->close();
			SMA_logout($host);
			return $r_FAIL;
		}
	}
	
	# All seems ok, logged in! 
	$socket->close();	
	return $r_OK;
}

####################################
sub SMA_logout($)
{
	# Parameters: host
	my $host = $_[0];
	my $cmdheader = "534D4100000402A00000000100";
	my $pktlength = "22";		# length = 34 for logout command
	my $esignature = "0010606508A0";
	my $cmd = "";
	my $myID = "";
	my $target_ID = "";
	my $spkt_ID = "";
	my $cmd_ID = "";
	my ($socket,$data,$size);
	
	# Define own ID and target ID and packet ID
	$myID = ByteOrderShort(substr(sprintf("%04X",$mysusyid),0,4)) . ByteOrderLong(sprintf("%08X",$myserialnumber));
	$target_ID = ByteOrderShort(substr(sprintf("%04X",$target_susyid),0,4)) . ByteOrderLong(sprintf("%08X",$target_serial));
	# Increasing Packet ID
	$pkt_ID = $pkt_ID + 1;	
	$spkt_ID = ByteOrderShort(sprintf("%04X",$pkt_ID));
	
	#Logout command
	$cmd_ID = "0E01FDFF" . "FFFFFFFF";  # Logout command

	#build final command to send
	$cmd = $cmdheader . $pktlength . $esignature . $target_ID . "0003" . $myID . "0003" . "00000000" . $spkt_ID . $cmd_ID . "00000000";

	# flush after every write
	$| = 1; 				
	
	# Create Socket and check if successful
	$socket = new IO::Socket::INET (PeerHost => $host, PeerPort => 9522, Proto => 'udp',); # open Socket

	if (!$socket) { 															
		# in case of error
		Log3 $globname, 1, "$globname: ERROR. Can't open socket to inverter: $!";
		return $r_FAIL;
	};
	
	# Send Data
	$data = pack("H*",$cmd);
	$socket->send($data);
	Log3 $globname, 4, "$globname: Send logout to $host on Port 9522";
	Log3 $globname, 5, "$globname: Send: $cmd ";
	
	Log3 $globname, 3, "$globname: Logged out now.";
	$socket->close();	
	return $r_OK;	
}

####################################
sub SMA_command($$$$)
{
	# Parameters: host - command - first - last
	my $host = $_[0];
	my $command = $_[1];
	my $first = $_[2];
	my $last = $_[3];
	my $cmdheader = "534D4100000402A00000000100";
	my $pktlength = "26";		# length = 38 for data commands
	my $esignature = "0010606509A0";
	my $cmd = "";
	my $myID = "";
	my $target_ID = "";
	my $spkt_ID = "";
	my $cmd_ID = "";
	my ($socket,$data,$size,$data_ID);
	
	use constant MAXBYTES => scalar 300;
	
	# Define own ID and target ID and packet ID
	$myID = ByteOrderShort(substr(sprintf("%04X",$mysusyid),0,4)) . ByteOrderLong(sprintf("%08X",$myserialnumber));
	$target_ID = ByteOrderShort(substr(sprintf("%04X",$target_susyid),0,4)) . ByteOrderLong(sprintf("%08X",$target_serial));
	# Increasing Packet ID
	$pkt_ID = $pkt_ID + 1;	
	$spkt_ID = ByteOrderShort(sprintf("%04X",$pkt_ID));

	$cmd_ID = ByteOrderLong(sprintf("%08X",$command)) . ByteOrderLong(sprintf("%08X",$first)) . ByteOrderLong(sprintf("%08X",$last));
	
	#build final command to send
	$cmd = $cmdheader . $pktlength . $esignature . $target_ID . "0000" . $myID . "0000" . "00000000" . $spkt_ID . $cmd_ID . "00000000";

	# flush after every write
	$| = 1; 				
	
	# Create Socket and check if successful
	$socket = new IO::Socket::INET (PeerHost => $host, PeerPort => 9522, Proto => 'udp',); # open Socket

	if (!$socket) { 															
		# in case of error
		Log3 $globname, 1, "$globname: ERROR. Can't open socket to inverter: $!";
		return $r_FAIL;
	};

	# Send Data
	$data = pack("H*",$cmd);
	$socket->send($data);
	Log3 $globname, 3, "$globname: Send request $cmd_ID to $host on port 9522";
	Log3 $globname, 5, "$globname: send: $cmd";
	
	# Receive Data and do a first check regarding length
	eval 
	{
		local $SIG{ALRM} = sub { die "alarm time out" };
		alarm 5;
		# receive data
		$socket->recv($data, MAXBYTES) or die "recv: $!";					
		$size = length($data);

		# check if something was received
		if (defined $size)															
		{
			my $received = unpack("H*", $data);
			Log3 $globname, 5, "$globname: Received: $received";
		}
		
		alarm 0;
		1;																	
	} or Log3 $globname, 1, "$globname query timed out";
	
	# Nothing received -> exit
	if (not defined $size)															
	{
		Log3 $globname, 1, "$globname: Nothing received...";
		return $r_FAIL;
	} else
	{
		# We have received something!
		
		if ($size > 58)
		{
			# Check all parameters of answer
			my $r_susyid = unpack("v*", substr $data, 20, 2);
			my $r_serial = unpack("V*", substr $data, 22, 4);
			my $r_pkt_ID = unpack("v*", substr $data, 40, 2);
			my $r_error  = unpack("V*", substr $data, 36, 4);
			if (($r_susyid ne $mysusyid) || ($r_serial ne $myserialnumber) || ($r_pkt_ID ne $pkt_ID) || ($r_error ne 0))
			{
				# Response does not match the parameters we have sent, maybe different target
				Log3 $globname, 3, "$globname: Inverter answer does not match our parameters.";
				Log3 $globname, 5, "$globname: Request/Response: SusyID $mysusyid/$r_susyid, Serial $myserialnumber/$r_serial, Packet ID $pkt_ID/$r_pkt_ID, Error $r_error";
				$socket->close();
				return $r_FAIL;
			}
			# ******************************************************************
			
		} else
		{
			Log3 $globname, 3, "$globname: Format of inverter response does not fit.";
			$socket->close();
			return $r_FAIL;
		}
	}
	
	# All seems ok, data received
	$inv_susyid = unpack("v*", substr $data, 28, 2);
	$inv_serial = unpack("V*", substr $data, 30, 4);
	
	my $cmd_identified = $r_FAIL;
	
	# Check the data identifier
	$data_ID = unpack("v*", substr $data, 55, 2);
	Log3 $globname, 5, "$globname: Data identifier $data_ID";
	if($data_ID eq 0x2601)	{
		$inv_SPOT_ETOTAL = unpack("V*", substr($data, 62, 4));
		$inv_SPOT_ETODAY = unpack("V*", substr $data, 78, 4);
		Log3 $globname, 5, "$globname: Found Data SPOT_ETOTAL=$inv_SPOT_ETOTAL and SPOT_ETODAY=$inv_SPOT_ETODAY";
		$cmd_identified = $r_OK;
	}
			
	if($data_ID eq 0x251E) {
		$inv_SPOT_PDC1 = unpack("V*", substr $data, 62, 4);
		$inv_SPOT_PDC2 = unpack("V*", substr $data, 90, 4);
		Log3 $globname, 5, "$globname: Found Data SPOT_PDC1=$inv_SPOT_PDC1 and SPOT_PDC2=$inv_SPOT_PDC2";
		$cmd_identified = $r_OK;
	} 
		
	if($data_ID eq 0x4640) {
		$inv_SPOT_PAC1 = unpack("l*", substr $data, 62, 4);
		$inv_SPOT_PAC2 = unpack("l*", substr $data, 90, 4);
		$inv_SPOT_PAC3 = unpack("l*", substr $data, 118, 4);
		Log3 $globname, 5, "$globname: Found Data SPOT_PAC1=$inv_SPOT_PAC1 and SPOT_PAC2=$inv_SPOT_PAC2 and SPOT_PAC3=$inv_SPOT_PAC3";
		$cmd_identified = $r_OK;
	}
		
	if($data_ID eq 0x411E) {
		$inv_PACMAX1 = unpack("V*", substr $data, 62, 4);
		$inv_PACMAX2 = unpack("V*", substr $data, 90, 4);
		$inv_PACMAX3 = unpack("V*", substr $data, 118, 4);
		Log3 $globname, 5, "$globname: Found Data INV_PACMAX1=$inv_PACMAX1 and INV_PACMAX2=$inv_PACMAX2 and INV_PACMAX3=$inv_PACMAX3";
		$cmd_identified = $r_OK;
	}
		
	if($data_ID eq 0x832A) {
		$inv_PACMAX1_2 = unpack("V*", substr $data, 62, 4);
		Log3 $globname, 5, "$globname: Found Data INV_PACMAX1_2=$inv_PACMAX1_2";
		$cmd_identified = $r_OK;
	}
		
	if($data_ID eq 0x263F) {
		$inv_SPOT_PACTOT = unpack("l*", substr $data, 62, 4);
		Log3 $globname, 5, "$globname: Found Data SPOT_PACTOT=$inv_SPOT_PACTOT";
		$cmd_identified = $r_OK;
	}
		
	if($data_ID eq 0x295A) {
		$inv_ChargeStatus = unpack("V*", substr $data, 62, 4);
		Log3 $globname, 5, "$globname: Found Data Battery Charge Status=$inv_ChargeStatus";
		$cmd_identified = $r_OK;
	}

	if($data_ID eq 0x451F) {
		if (substr($data, 62, 4) ne 0xFFFFFFFF) { $inv_SPOT_UDC1 = unpack("l*", substr $data, 62, 4) / 100; } else { $inv_SPOT_UDC1 = 0; }
		if (substr($data, 90, 4) ne 0xFFFFFFFF) { $inv_SPOT_UDC2 = unpack("l*", substr $data, 90, 4) / 100; } else { $inv_SPOT_UDC2 = 0; }
		if (substr($data, 118, 4) ne 0xFFFFFFFF) { $inv_SPOT_IDC1 = unpack("l*", substr $data, 118, 4) / 1000; } else { $inv_SPOT_IDC1 = 0; }
		if (substr($data, 146, 4) ne 0xFFFFFFFF) { $inv_SPOT_IDC2 = unpack("l*", substr $data, 146, 4) / 1000; } else { $inv_SPOT_IDC2 = 0; }
		Log3 $globname, 5, "$globname: Found Data SPOT_UDC1=$inv_SPOT_UDC1 and SPOT_UDC2=$inv_SPOT_UDC2 and SPOT_IDC1=$inv_SPOT_IDC1 and SPOT_IDC2=$inv_SPOT_IDC2";
		$cmd_identified = $r_OK;
	}

	if($data_ID eq 0x4648) {
		if (substr($data, 62, 4) ne 0xFFFFFFFF) { $inv_SPOT_UAC1 = unpack("l*", substr $data, 62, 4) / 100; } else { $inv_SPOT_UAC1 = 0; }
		if (substr($data, 90, 4) ne 0xFFFFFFFF) { $inv_SPOT_UAC2 = unpack("l*", substr $data, 90, 4) / 100; } else { $inv_SPOT_UAC2 = 0; }
		if (substr($data, 118, 4) ne 0xFFFFFFFF) { $inv_SPOT_UAC3 = unpack("l*", substr $data, 118, 4) / 100; } else { $inv_SPOT_UAC3 = 0; }
		if (substr($data, 146, 4) ne 0xFFFFFFFF) { $inv_SPOT_IAC1 = unpack("l*", substr $data, 146, 4) / 1000; } else { $inv_SPOT_IAC1 = 0; }
		if (substr($data, 174, 4) ne 0xFFFFFFFF) { $inv_SPOT_IAC2 = unpack("l*", substr $data, 174, 4) / 1000; } else { $inv_SPOT_IAC2 = 0; }
		if (substr($data, 202, 4) ne 0xFFFFFFFF) { $inv_SPOT_IAC3 = unpack("l*", substr $data, 202, 4) / 1000; } else { $inv_SPOT_IAC3 = 0; }
		Log3 $globname, 5, "$globname: Found Data SPOT_UAC1=$inv_SPOT_UAC1 and SPOT_UAC2=$inv_SPOT_UAC2 and SPOT_UAC3=$inv_SPOT_UAC3 and SPOT_IAC1=$inv_SPOT_IAC1 and SPOT_IAC2=$inv_SPOT_IAC2 and SPOT_IAC3=$inv_SPOT_IAC3";
		$cmd_identified = $r_OK;
	}

	if($data_ID eq 0x491E) {
		$inv_BAT_CYCLES = unpack("V*", substr $data, 62, 4);
		$inv_BAT_TEMP = unpack("V*", substr $data, 90, 4) / 10; 
		$inv_BAT_UDC = unpack("V*", substr $data, 118, 4) / 100;
		$inv_BAT_IDC = unpack("l*", substr $data, 146, 4) / 1000; 
		Log3 $globname, 5, "$globname: Found Data BAT_CYCLES=$inv_BAT_CYCLES and BAT_TEMP=$inv_BAT_TEMP and BAT_UDC=$inv_BAT_UDC and BAT_IDC=$inv_BAT_IDC";
		$cmd_identified = $r_OK;
	}

	if($data_ID eq 0x2377) {
		$inv_TEMP = unpack("l*", substr $data, 62, 4) / 100;
		Log3 $globname, 5, "$globname: Found Data Inverter Temp=$inv_TEMP";
		$cmd_identified = $r_OK;
	}

	if($data_ID eq 0x462E) {
		$inv_SPOT_OPERTM = int(unpack("V*", substr $data, 62, 4) / 36) / 100;
		$inv_SPOT_FEEDTM = int(unpack("V*", substr $data, 78, 4) / 36) / 100;
		Log3 $globname, 5, "$globname: Found Data SPOT_OPERTM=$inv_SPOT_OPERTM and SPOT_FEEDTM=$inv_SPOT_FEEDTM";
		$cmd_identified = $r_OK;
	}

	if($data_ID eq 0x4657) {
		$inv_SPOT_FREQ = unpack("V*", substr $data, 62, 4) / 100;
		Log3 $globname, 5, "$globname: Found Data SPOT_FREQ=$inv_SPOT_FREQ";
		$cmd_identified = $r_OK;
	}

	if($data_ID eq 0x821E) {
		$inv_CLASS = unpack("V*", substr $data, 102, 4) & 0x00FFFFFF;
		$inv_TYPE = unpack("V*", substr $data, 142, 4) & 0x00FFFFFF;
		Log3 $globname, 5, "$globname: Found Data CLASS=$inv_CLASS and TYPE=$inv_TYPE";
		$cmd_identified = $r_OK;
	}
	
	$socket->close();	
	return $cmd_identified;
}

####################################
sub ByteOrderShort($)
{
	my $input = $_[0];
	my $output = "";
	$output = substr($input, 2, 2) . substr($input, 0, 2);
	return $output;
}

####################################
sub ByteOrderLong($)
{
	my $input = $_[0];
	my $output = "";
	$output = substr($input, 6, 2) . substr($input, 4, 2) . substr($input, 2, 2) . substr($input, 0, 2);
	return $output;
}


1;

=pod

=begin html

<a name="SMAInverter"></a>
<h3>SMAInverter</h3>

*** To be written...

=end html_DE
