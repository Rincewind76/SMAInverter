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
#  - rewritten by Thomas Schoedl (sct14675) with inputs from Volker, waldmensch and DS_starter
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

# Reporting (=Reading) detail level: 
# 0 - Standard (only power and energy), 1 - More details(including current and voltage), 2 - All Data
my $detail_level = 0;
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
my $inv_GRIDRELAY = 0;							# Grid Relay/Contactor Status
my $sup_GridRelayStatus = $r_FAIL;	# GridRelayStatus command supported


###################################
sub SMAInverter_Initialize($)
{
	my ($hash) = @_;
	my $name = $hash->{NAME};
	my $hval;
	my $mval;

	$hash->{DefFn}     = "SMAInverter_Define";
	$hash->{UndefFn}   = "SMAInverter_Undef";
	$hash->{AttrList}  = "interval " . 
						"detail-level:0,1,2 " .
						"target-susyid " .
						"target-serial " .
						$readingFnAttributes;
	$hash->{AttrFn}   = "SMAInverter_Attr";
	
	$detail_level = ($attr{$name}{"detail-level"}) ? $attr{$name}{"detail-level"} : 0;
	$target_susyid = ($attr{$name}{"target-susyid"}) ? $attr{$name}{"target-susyid"} : $default_target_susyid;
	$target_serial = ($attr{$name}{"target-serial"}) ? $attr{$name}{"target-serial"} : $default_target_serial;
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
		delete $defs{$name}{READINGS};
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
		
	# Get current time
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
	
	# For logging events set the module name
	$globname = $name;
	
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

					# Check MaxACPower
					$sup_MaxACPower = SMA_command($hash->{Host}, 0x51000200, 0x00411E00, 0x004120FF);
	
					# Check MaxACPower2
					$sup_MaxACPower2 = SMA_command($hash->{Host}, 0x51000200, 0x00832A00, 0x00832AFF);

					# Check GridRelayStatus
					$sup_GridRelayStatus = SMA_command($hash->{Host}, 0x51800200, 0x00416400, 0x004164FF);
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

					if($sup_MaxACPower eq $r_OK) {
						readingsBulkUpdate($hash, "INV_PACMAX1", $inv_PACMAX1);
						readingsBulkUpdate($hash, "INV_PACMAX2", $inv_PACMAX2);					
						readingsBulkUpdate($hash, "INV_PACMAX3", $inv_PACMAX3);					
					}				
					if($sup_MaxACPower2 eq $r_OK) {
						readingsBulkUpdate($hash, "INV_PACMAX1_2", $inv_PACMAX1_2);					
					}				
					
					if($sup_InverterTemperature eq $r_OK) {
						readingsBulkUpdate($hash, "INV_TEMP", $inv_TEMP);
					}
					
					if($sup_OperationTime eq $r_OK) {
						readingsBulkUpdate($hash, "SPOT_FEEDTM", $inv_SPOT_FEEDTM);
						readingsBulkUpdate($hash, "SPOT_OPERTM", $inv_SPOT_OPERTM);
					}
					
					if($sup_GridRelayStatus eq $r_OK) {
						readingsBulkUpdate($hash, "INV_GRIDRELAY", StatusText($inv_GRIDRELAY));
					}
				}
													
				readingsEndUpdate($hash, 1);	# Notify is done by Dispatch
				$hash->{LASTUPDATE} = sprintf "%02d.%02d.%04d / %02d:%02d:%02d" , $mday , $mon+=1 ,$year+=1900 , $hour , $min , $sec ;	
		} else
		{
				# Login failed/not possible
				readingsBeginUpdate($hash);
				readingsBulkUpdate($hash, "state", "Login failed");
				readingsBulkUpdate($hash, "modulstate", "login failed");
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
	my ($i, $temp); 			# Variables for loops and calculation
	
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
	$socket->close();	
		
	my $cmd_identified = $r_FAIL;
	
	# Check the data identifier
	$data_ID = unpack("v*", substr $data, 55, 2);
	Log3 $globname, 5, "$globname: Data identifier $data_ID";
	if($data_ID eq 0x2601)	{
		$inv_SPOT_ETOTAL = unpack("V*", substr($data, 62, 4));
		$inv_SPOT_ETODAY = unpack("V*", substr $data, 78, 4);
		Log3 $globname, 5, "$globname: Found Data SPOT_ETOTAL=$inv_SPOT_ETOTAL and SPOT_ETODAY=$inv_SPOT_ETODAY";
		return $r_OK;
	}
			
	if($data_ID eq 0x251E) {
		$inv_SPOT_PDC1 = unpack("V*", substr $data, 62, 4);
		$inv_SPOT_PDC2 = unpack("V*", substr $data, 90, 4);
		Log3 $globname, 5, "$globname: Found Data SPOT_PDC1=$inv_SPOT_PDC1 and SPOT_PDC2=$inv_SPOT_PDC2";
		return $r_OK;
	} 
		
	if($data_ID eq 0x4640) {
		$inv_SPOT_PAC1 = unpack("l*", substr $data, 62, 4);
		if($inv_SPOT_PAC1 eq 0x80000000) {$inv_SPOT_PAC1 = 0; }	# Catch 0x80000000 as 0 value
		$inv_SPOT_PAC2 = unpack("l*", substr $data, 90, 4);
		if($inv_SPOT_PAC2 eq 0x80000000) {$inv_SPOT_PAC2 = 0; }	# Catch 0x80000000 as 0 value
		$inv_SPOT_PAC3 = unpack("l*", substr $data, 118, 4);
		if($inv_SPOT_PAC3 eq 0x80000000) {$inv_SPOT_PAC3 = 0; }	# Catch 0x80000000 as 0 value
		Log3 $globname, 5, "$globname: Found Data SPOT_PAC1=$inv_SPOT_PAC1 and SPOT_PAC2=$inv_SPOT_PAC2 and SPOT_PAC3=$inv_SPOT_PAC3";
		return $r_OK;
	}
		
	if($data_ID eq 0x411E) {
		$inv_PACMAX1 = unpack("V*", substr $data, 62, 4);
		$inv_PACMAX2 = unpack("V*", substr $data, 90, 4);
		$inv_PACMAX3 = unpack("V*", substr $data, 118, 4);
		Log3 $globname, 5, "$globname: Found Data INV_PACMAX1=$inv_PACMAX1 and INV_PACMAX2=$inv_PACMAX2 and INV_PACMAX3=$inv_PACMAX3";
		return $r_OK;
	}
		
	if($data_ID eq 0x832A) {
		$inv_PACMAX1_2 = unpack("V*", substr $data, 62, 4);
		Log3 $globname, 5, "$globname: Found Data INV_PACMAX1_2=$inv_PACMAX1_2";
		return $r_OK;
	}
		
	if($data_ID eq 0x263F) {
		$inv_SPOT_PACTOT = unpack("l*", substr $data, 62, 4);
		if($inv_SPOT_PACTOT eq 0x80000000) {$inv_SPOT_PACTOT = 0; }	# Catch 0x80000000 as 0 value
		Log3 $globname, 5, "$globname: Found Data SPOT_PACTOT=$inv_SPOT_PACTOT";
		return $r_OK;
	}
		
	if($data_ID eq 0x295A) {
		$inv_ChargeStatus = unpack("V*", substr $data, 62, 4);
		Log3 $globname, 5, "$globname: Found Data Battery Charge Status=$inv_ChargeStatus";
		return $r_OK;
	}

	if($data_ID eq 0x451F) {
		$inv_SPOT_UDC1 = unpack("l*", substr $data, 62, 4);
		$inv_SPOT_UDC2 = unpack("l*", substr $data, 90, 4);
		$inv_SPOT_IDC1 = unpack("l*", substr $data, 118, 4);
		$inv_SPOT_IDC2 = unpack("l*", substr $data, 146, 4);
		if(($inv_SPOT_UDC1 eq 0x80000000) || ($inv_SPOT_UDC1 eq 0xFFFFFFFF)) {$inv_SPOT_UDC1 = 0; } else {$inv_SPOT_UDC1 = $inv_SPOT_UDC1 / 100; }	# Catch 0x80000000 and 0xFFFFFFFF as 0 value
		if(($inv_SPOT_UDC2 eq 0x80000000) || ($inv_SPOT_UDC2 eq 0xFFFFFFFF)) {$inv_SPOT_UDC2 = 0; } else {$inv_SPOT_UDC2 = $inv_SPOT_UDC2 / 100; }	# Catch 0x80000000 and 0xFFFFFFFF as 0 value
		if(($inv_SPOT_IDC1 eq 0x80000000) || ($inv_SPOT_IDC1 eq 0xFFFFFFFF)) {$inv_SPOT_IDC1 = 0; } else {$inv_SPOT_IDC1 = $inv_SPOT_IDC1 / 1000; }	# Catch 0x80000000 and 0xFFFFFFFF as 0 value
		if(($inv_SPOT_IDC2 eq 0x80000000) || ($inv_SPOT_IDC2 eq 0xFFFFFFFF)) {$inv_SPOT_IDC2 = 0; } else {$inv_SPOT_IDC2 = $inv_SPOT_IDC2 / 1000; }	# Catch 0x80000000 and 0xFFFFFFFF as 0 value
		Log3 $globname, 5, "$globname: Found Data SPOT_UDC1=$inv_SPOT_UDC1 and SPOT_UDC2=$inv_SPOT_UDC2 and SPOT_IDC1=$inv_SPOT_IDC1 and SPOT_IDC2=$inv_SPOT_IDC2";
		return $r_OK;
	}

	if($data_ID eq 0x4648) {
		$inv_SPOT_UAC1 = unpack("l*", substr $data, 62, 4);
		$inv_SPOT_UAC2 = unpack("l*", substr $data, 90, 4);
		$inv_SPOT_UAC3 = unpack("l*", substr $data, 118, 4);
		$inv_SPOT_IAC1 = unpack("l*", substr $data, 146, 4);
		$inv_SPOT_IAC2 = unpack("l*", substr $data, 174, 4);
		$inv_SPOT_IAC3 = unpack("l*", substr $data, 202, 4);
		if(($inv_SPOT_UAC1 eq 0x80000000) || ($inv_SPOT_UAC1 eq 0xFFFFFFFF)) {$inv_SPOT_UAC1 = 0; } else {$inv_SPOT_UAC1 = $inv_SPOT_UAC1 / 100; }	# Catch 0x80000000 and 0xFFFFFFFF as 0 value
		if(($inv_SPOT_UAC2 eq 0x80000000) || ($inv_SPOT_UAC2 eq 0xFFFFFFFF)) {$inv_SPOT_UAC2 = 0; } else {$inv_SPOT_UAC2 = $inv_SPOT_UAC2 / 100; }	# Catch 0x80000000 and 0xFFFFFFFF as 0 value
		if(($inv_SPOT_UAC3 eq 0x80000000) || ($inv_SPOT_UAC3 eq 0xFFFFFFFF)) {$inv_SPOT_UAC3 = 0; } else {$inv_SPOT_UAC3 = $inv_SPOT_UAC3 / 100; }	# Catch 0x80000000 and 0xFFFFFFFF as 0 value
		if(($inv_SPOT_IAC1 eq 0x80000000) || ($inv_SPOT_IAC1 eq 0xFFFFFFFF)) {$inv_SPOT_IAC1 = 0; } else {$inv_SPOT_IAC1 = $inv_SPOT_IAC1 / 1000; }	# Catch 0x80000000 and 0xFFFFFFFF as 0 value
		if(($inv_SPOT_IAC2 eq 0x80000000) || ($inv_SPOT_IAC2 eq 0xFFFFFFFF)) {$inv_SPOT_IAC2 = 0; } else {$inv_SPOT_IAC2 = $inv_SPOT_IAC2 / 1000; }	# Catch 0x80000000 and 0xFFFFFFFF as 0 value
		if(($inv_SPOT_IAC3 eq 0x80000000) || ($inv_SPOT_IAC3 eq 0xFFFFFFFF)) {$inv_SPOT_IAC3 = 0; } else {$inv_SPOT_IAC3 = $inv_SPOT_IAC3 / 1000; }	# Catch 0x80000000 and 0xFFFFFFFF as 0 value
		Log3 $globname, 5, "$globname: Found Data SPOT_UAC1=$inv_SPOT_UAC1 and SPOT_UAC2=$inv_SPOT_UAC2 and SPOT_UAC3=$inv_SPOT_UAC3 and SPOT_IAC1=$inv_SPOT_IAC1 and SPOT_IAC2=$inv_SPOT_IAC2 and SPOT_IAC3=$inv_SPOT_IAC3";
		return $r_OK;
	}

	if($data_ID eq 0x491E) {
		$inv_BAT_CYCLES = unpack("V*", substr $data, 62, 4);
		$inv_BAT_TEMP = unpack("V*", substr $data, 90, 4) / 10; 
		$inv_BAT_UDC = unpack("V*", substr $data, 118, 4) / 100;
		$inv_BAT_IDC = unpack("l*", substr $data, 146, 4); 
		if($inv_BAT_IDC eq 0x80000000) {$inv_BAT_IDC = 0; } else { $inv_BAT_IDC = $inv_BAT_IDC / 1000;} 	# Catch 0x80000000 as 0 value
		Log3 $globname, 5, "$globname: Found Data BAT_CYCLES=$inv_BAT_CYCLES and BAT_TEMP=$inv_BAT_TEMP and BAT_UDC=$inv_BAT_UDC and BAT_IDC=$inv_BAT_IDC";
		return $r_OK;
	}

	if($data_ID eq 0x2377) {
		$inv_TEMP = unpack("l*", substr $data, 62, 4);
		if($inv_TEMP eq 0x80000000) {$inv_TEMP = 0; } else { $inv_TEMP = $inv_TEMP / 100;} 	# Catch 0x80000000 as 0 value
		Log3 $globname, 5, "$globname: Found Data Inverter Temp=$inv_TEMP";
		return $r_OK;
	}

	if($data_ID eq 0x462E) {
		$inv_SPOT_OPERTM = int(unpack("V*", substr $data, 62, 4) / 36) / 100;
		$inv_SPOT_FEEDTM = int(unpack("V*", substr $data, 78, 4) / 36) / 100;
		Log3 $globname, 5, "$globname: Found Data SPOT_OPERTM=$inv_SPOT_OPERTM and SPOT_FEEDTM=$inv_SPOT_FEEDTM";
		return $r_OK;
	}

	if($data_ID eq 0x4657) {
		$inv_SPOT_FREQ = unpack("V*", substr $data, 62, 4) / 100;
		Log3 $globname, 5, "$globname: Found Data SPOT_FREQ=$inv_SPOT_FREQ";
		return $r_OK;
	}

	if($data_ID eq 0x821E) {
		$inv_CLASS = unpack("V*", substr $data, 102, 4) & 0x00FFFFFF;
		$inv_TYPE = unpack("V*", substr $data, 142, 4) & 0x00FFFFFF;
		Log3 $globname, 5, "$globname: Found Data CLASS=$inv_CLASS and TYPE=$inv_TYPE";
		return $r_OK;
	}

	if($data_ID eq 0x4164) {
		$i = 0;
		$temp = 0;
		$inv_GRIDRELAY = 0x00FFFFFD;		# Code for No Information;
		do
		{
			$temp = unpack("V*", substr $data, 62 + $i*4, 4);
			if(($temp & 0xFF000000) ne 0) { $inv_GRIDRELAY = $temp & 0x00FFFFFF; }
			$i = $i + 1;
		} while ((unpack("V*", substr $data, 62 + $i*4, 4) ne 0x00FFFFFE) && ($i < 5));
		Log3 $globname, 5, "$globname: Found Data INV_GRIDRELAY=$inv_GRIDRELAY";
		return $r_OK;
	}
	
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

####################################
sub StatusText($)
{
	# Parameter is the code, return value is the Text or if not known then the code as string
	my $code = $_[0];
	
	if($code eq 51) { return "Closed"; }
	if($code eq 311) { return "Open"; }
	if($code eq 16777213) { return "No Information"; }
	
	return sprintf("%d", $code);
}

1;

=pod

=begin html

<a name="SMAInverter"></a>
<h3>SMAInverter</h3>

Module for the integration of a SMA Inverter over it's Speedwire (=Ethernet) Interface.<br>
Tested on Sunny Tripower 6000TL-20 and Sunny Island 4.4 with Speedwire/Webconnect Piggyback.

<p>

<b>Requirements:</b> 
This module requires:
<ul>
    <li>Perl Module: IO::Socket::INET</li>
    <li>Perl Module: Datetime</li>
</ul>
Installation e.g. with sudo apt-get install libdatetime-perl libio-socket-multicast-perl

<p>

<b>Define</b>
<ul>
<code>define &lt;name&gt; SMAInverter &lt;pin&gt; &lt;hostname/ip&gt; </code><br>
<br>
<li>pin: User-Password of the SMA Inverter. Default is 0000. Can be changed by "Sunny Explorer" Windows Software</li>
<li>hostname/ip: Hostname or IP-Adress of the inverter (or it's speedwire piggyback module).</li>
<li>Port of the inverter is 9522 by default. Firewall has to allow connection on this port!</li>
</ul>

<p>

<b>Modus</b>
<ul>
The module sends commands to the inverter and checks if they are supported by the inverter.<br>
In case of a positive answer the data is collected and displayed in the readings according to the detail-level.
</ul>

<b>Parameter</b>
<ul>
	<li>interval: Queryintreval in seconds </li>
	<li>detail-level: "0" - Only Power and Energy / "1" - Including Voltage and Current / "2" - All values
	<li>target-susyid: In case of a Multigate the target SUSyID can be defined. Default is 0xFFFF, means any SUSyID</li>
	<li>target-serial: In case of a Multigate the target Serialnumber can be defined. Default is 0xFFFFFFFF, means any Serialnumber</li>	
</ul>

<b>Readings</b>
 <ul>
<li>BAT_CYCLES :  Battery recharge cycles </li>
<li>BAT_IDC :  Battery Current </li>
<li>BAT_TEMP :  Battery temperature </li>
<li>BAT_UDC :  Battery Voltage </li>
<li>ChargeStatus :  Battery Charge status </li>
<li>CLASS :  Inverter Class </li>
<li>PACMAX1 :  Nominal power in Ok Mode </li>
<li>PACMAX1_2 :  Maximum active power device (Some inverters like SB3300/SB1200) </li>
<li>PACMAX2 :  Nominal power in Warning Mode </li>
<li>PACMAX3 :  Nominal power in Fault Mode </li>
<li>Serialnumber :  Inverter Serialnumber </li>
<li>SPOT_ETODAY :  Today yield </li>
<li>SPOT_ETOTAL :  Total yield </li>
<li>SPOT_FEEDTM :  Feed-in time </li>
<li>SPOT_FREQ :  Grid Frequency </li>
<li>SPOT_IAC1 :  Grid current phase L1 </li>
<li>SPOT_IAC2 :  Grid current phase L2 </li>
<li>SPOT_IAC3 :  Grid current phase L3 </li>
<li>SPOT_IDC1 :  DC current input </li>
<li>SPOT_IDC2 :  DC current input </li>
<li>SPOT_OPERTM :  Operation Time </li>
<li>SPOT_PAC1 :  Power L1  </li>
<li>SPOT_PAC2 :  Power L2  </li>
<li>SPOT_PAC3 :  Power L3  </li>
<li>SPOT_PACTOT :  Total Power </li>
<li>SPOT_PDC1 :  DC power input 1 </li>
<li>SPOT_PDC2 :  DC power input 2 </li>
<li>SPOT_UAC1 :  Grid voltage phase L1 </li>
<li>SPOT_UAC2 :  Grid voltage phase L2 </li>
<li>SPOT_UAC3 :  Grid voltage phase L3 </li>
<li>SPOT_UDC1 :  DC voltage input </li>
<li>SPOT_UDC2 :  DC voltage input </li>
<li>SUSyID :  Inverter SUSyID </li>
<li>INV_TEMP :  Inverter temperature </li>
<li>INV_TYPE :  Inverter Type </li>
<li>POWER_IN :  Battery Charging power </li>
<li>POWER_OUT :  Battery Discharging power </li>
<li>INV_GRIDRELAY : Grid Relay/Contactor Status </li>

 </ul>


=end html


=begin html_DE

<a name="SMAInverter"></a>
<h3>SMAInverter</h3>

Modul zur Einbindung eines SMA Wechselrichters über Speedwire (Ethernet).<br>
Getestet mit Sunny Tripower 6000TL-20 und Sunny Island 4.4 mit Speedwire/Webconnect Piggyback

<p>

<b>Voraussetzungen:</b> 
Dieses Modul benötigt:
<ul>
    <li>Perl Module: IO::Socket::INET</li>
    <li>Perl Module: Datetime</li>
</ul>
Installation z.B. mit sudo apt-get install libdatetime-perl libio-socket-multicast-perl

<p>

<b>Define</b>
<ul>
<code>define &lt;name&gt; SMAInverter &lt;pin&gt; &lt;hostname/ip&gt; [port]</code><br>
<br>
<li>pin: Benutzer-Passwort des SMA STP Wechselrichters. Default ist 0000. Kann über die Windows-Software "Sunny Explorer" geändert werden </li>
<li>hostname/ip: Hostname oder IP-Adresse des Wechselrichters (bzw. dessen Speedwire Moduls mit Ethernetanschluss) </li>
<li>Der Ports des Wechselrichters ist standardmäßig 9522. Dieser Port muss in der Firewall freigeschalten sein!</li>
</ul>

<p>

<b>Modus</b>
<ul>
Das Modul schickt Befehle an den Wechselrichter und überprüft, ob diese unterstützt werden.<br>
Bei einer positiven Antwort werden die Daten gesammelt und je nach Detail-Level in den Readings dargestellt.<br>
</ul>

<b>Parameter</b>
<ul>
	<li>interval: Abfrageinterval in Sekunden </li>
	<li>detail-level: "0" - Nur Leistung und Energie / "1" - zusätzlich Strom und Spannung / "2" - Alle Werte
	<li>target-susyid: Im Falle eines Multigate kann die Ziel-SUSyID definiert werden. Default ist 0xFFFF (=keine Einschränkunng)</li>
	<li>target-serial: Im Falle eines Multigate kann die Ziel-Seriennummer definiert werden. Default ist 0xFFFFFFFF (=keine Einschränkunng)</li>	
</ul>

<b>Readings</b>
 <ul>
<li>BAT_CYCLES :  Akku Ladezyklen </li>
<li>BAT_IDC :  Akku Strom </li>
<li>BAT_TEMP :  Akku Temperatur </li>
<li>BAT_UDC :  Akku Spannung </li>
<li>ChargeStatus :  Akku Ladestand </li>
<li>CLASS :  Wechselrichter Klasse </li>
<li>PACMAX1 :  Nominelle Leistung in Ok Mode </li>
<li>PACMAX1_2 :  Maximale Leistung (für einige Wechselrichtertypen) </li>
<li>PACMAX2 :  Nominelle Leistung in Warning Mode </li>
<li>PACMAX3 :  Nominelle Leistung in Fault Mode </li>
<li>Serialnumber :  Wechselrichter Seriennummer </li>
<li>SPOT_ETODAY :  Energie heute</li>
<li>SPOT_ETOTAL :  Energie Insgesamt </li>
<li>SPOT_FEEDTM :  Einspeise-Stunden </li>
<li>SPOT_FREQ :  Netz Frequenz </li>
<li>SPOT_IAC1 :  Netz Strom phase L1 </li>
<li>SPOT_IAC2 :  Netz Strom phase L2 </li>
<li>SPOT_IAC3 :  Netz Strom phase L3 </li>
<li>SPOT_IDC1 :  DC Strom Eingang 1 </li>
<li>SPOT_IDC2 :  DC Strom Eingang 2 </li>
<li>SPOT_OPERTM :  Betriebsstunden </li>
<li>SPOT_PAC1 :  Leistung L1  </li>
<li>SPOT_PAC2 :  Leistung L2  </li>
<li>SPOT_PAC3 :  Leistung L3  </li>
<li>SPOT_PACTOT :  Gesamtleistung </li>
<li>SPOT_PDC1 :  DC Leistung Eingang 1 </li>
<li>SPOT_PDC2 :  DC Leistung Eingang 2 </li>
<li>SPOT_UAC1 :  Netz Spannung phase L1 </li>
<li>SPOT_UAC2 :  Netz Spannung phase L2 </li>
<li>SPOT_UAC3 :  Netz Spannung phase L3 </li>
<li>SPOT_UDC1 :  DC Spannung Eingang 1 </li>
<li>SPOT_UDC2 :  DC Spannung Eingang 2 </li>
<li>SUSyID :  Wechselrichter SUSyID </li>
<li>INV_TEMP :  Wechselrichter Temperatur </li>
<li>INV_TYPE :  Wechselrichter Typ </li>
<li>POWER_IN :  Akku Ladeleistung </li>
<li>POWER_OUT :  Akku Entladeleistung </li>
<li>INV_GRIDRELAY : Netz Relais Status </li>
 </ul>


=end html_DE

