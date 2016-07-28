# 76_SMAInverter.pm
FHEM Support for SMA Inverters

Copyright notice<br>
Published according Creative Commons : Attribution-NonCommercial-ShareAlike 3.0 Unported (CC BY-NC-SA 3.0)<br>
Details: https://creativecommons.org/licenses/by-nc-sa/3.0/

<br>

Credits:
- based on 77_SMASTP.pm by Volker Kettenbach with following credits:
- based on an Idea by SpenZerX and HDO
- Waldmensch for various improvements
- sbfspot (https://sbfspot.codeplex.com/)

<p>

Rewritten by Thomas Schödl (sct14675) with inputs from Volker, Waldmensch and DS_starter

Description:<br>
Module for the integration of a SMA Inverter over it's Speedwire (=Ethernet) Interface in FHEM.<br>
Tested on Sunny Tripower 6000TL-20 and Sunny Island 4.4 with Speedwire/Webconnect Piggyback.

<p>

<b>Requirements:</b> <br>
This module requires:
<ul>
    <li>Perl Module: IO::Socket::INET</li>
    <li>Perl Module: Datetime</li>
</ul>
Installation e.g. with sudo apt-get install libdatetime-perl libio-socket-multicast-perl

<p>
<b>Define</b><br>
The module 76_SMAInverter.pm has to be copied to the /FHEM directory of the installation of FHEM.<br>
example: /opt/fhem/FHEM<br>
The module itself has to be loaded in FHEM with the command:<br>
<code>reload 76_SMAInverter.pm</code><br>

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

 </ul>

