#76_SMAInverter.pm
FHEM Support for SMA Inverters over "Speedwire" TCP/IP network

##Description##
Module for the integration of a SMA Inverter over it's Speedwire (=Ethernet) Interface.

Tested on Sunny Tripower 6000TL-20, 10000TL-20 and Sunny Island 4.4 with Speedwire/Webconnect Piggyback.

###Requirements###
This module requires:

* Perl Module: IO::Socket::INET  (apt-get install libio-socket-perl)
* Perl Module: Date::Time        (apt-get install libdatetime-perl)
* Perl Module: Time::HiRes			(In Debian/Ubuntu/Raspbian part of default per installation)
* FHEM Module: 99_SUNRISE_EL.pm
* FHEM Module: Blocking.pm

###Define###

``define <name> SMAInverter <pin> <hostname/ip>``

* pin: User-Password of the SMA Inverter. Default is 0000. Can be changed by "Sunny Explorer" Windows Software
* hostname/ip: Hostname or IP-Adress of the inverter (or it's speedwire piggyback module).
* Port of the inverter is 9522 by default. Firewall has to allow connections on this port!


###Operation method####
The module sends commands to the inverter and checks if they are supported by the inverter. In case of a positive answer, the data is collected and displayed in the readings according to the detail-level.

If more than one inverter is installed, set attributes "target-susyid" and "target-serial" with an appropriate value. 

The normal operation time of the inverter is supposed from sunrise to sunset. In that time period the inverter will be polled.
The time of sunrise and sunset will be calculated by functions of FHEM module 99_SUNRISE_EL.pm which is loaded automatically by default. 
Therefore the global attribute "longitude" and "latitude" should be set to determine the position of the solar system 


By the attribute "suppressSleep" the sleep mode between sunset and sunrise can be suppressed. Using attribute "offset" you may prefer the sunrise and
defer the sunset virtually. So the working period of the inverter will be extended. 


In operating mode "automatic" the inverter will be requested periodically corresponding the preset attribute "interval". The operating mode can be 
switched to "manual" to realize the retrieval manually (e.g. to synchronize the requst with a SMA energy meter by notify).


During inverter operating time, the average energy production of the last 5, 10 and 15 minutes will be calculated and displayed in the readings  

``"avg_power_lastminutes_05"``

``"avg_power_lastminutes_10" ``

and 

``"avg_power_lastminutes_15".```

**Note:** To permit a precise calculation, you should also set the real request interval into the attribute "interval" although you would use the "manual" operation mode !

The retrieval of the inverter will be executed non-blocking. You can adjust the timeout value for this background process by attribute "timeout".


###Get###

``get <name> data``

The request of the inverter will be executed. Those possibility is especifically created for the "manual" operation mode (see attribute "mode").


####Attributes###

<ul>

  <li><b>interval</b>       : Queryintreval in seconds </li>

  <li><b>detail-level</b>   : "0" - Only Power and Energy / "1" - Including Voltage and Current / "2" - All values </li>

  <li><b>disable</b>        : 1 = the module is disabled </li>

  <li><b>mode</b>           : automatic = the inverter will be polled by preset interval, manual = query only by command "get &lt;name&gt; data" </li>

  <li><b>offset</b>         : time in seconds to prefer the sunrise respectively defer the sunset virtualy (0 ... 7200).  You will be able to extend the working

                              period of the module. </li>

  <li><b>SBFSpotComp</b>    : 1 = the readings are created like SBFSpot-style </li>

  <li><b>suppressSleep</b>  : the sleep mode (after sunset, before sunrise) is deactivated and the inverter will be polled continuously.  </li>

  <li><b>showproctime</b>   : shows processing time in background and wasted time to retrieve inverter data  </li>

  <li><b>target-susyid</b>  : In case of a Multigate the target SUSyID can be defined. If more than one inverter is installed you have to

                              set the inverter-SUSyID to assign the inverter to the device definition.

                              Default is 0xFFFF, means any SUSyID</li>

  <li><b>target-serial</b>  : In case of a Multigate the target Serialnumber can be defined. If more than one inverter is installed you have to

                              set the inverter-Serialnumber to assign the inverter to the device definition.

							  Default is 0xFFFFFFFF, means any Serialnumber</li>

  <li><b>timeout</b>        : setup timeout of inverter data request (default 60s) </li>  

</ul>



###Readings####

<ul>

<li><b>BAT_CYCLES / bat_cycles</b>          :  Battery recharge cycles </li>

<li><b>BAT_IDC / bat_idc</b>                :  Battery Current </li>

<li><b>BAT_TEMP / bat_temp</b>              :  Battery temperature </li>

<li><b>BAT_UDC / bat_udc</b>                :  Battery Voltage </li>

<li><b>ChargeStatus / chargestatus</b>      :  Battery Charge status </li>

<li><b>CLASS / device_class</b>             :  Inverter Class </li>

<li><b>PACMAX1 / pac_max_phase_1</b>        :  Nominal power in Ok Mode </li>

<li><b>PACMAX1_2 / pac_max_phase_1_2</b>    :  Maximum active power device (Some inverters like SB3300/SB1200) </li>

<li><b>PACMAX2 / pac_max_phase_2</b>        :  Nominal power in Warning Mode </li>

<li><b>PACMAX3 / pac_max_phase_3</b>        :  Nominal power in Fault Mode </li>

<li><b>Serialnumber / serial_number</b>     :  Inverter Serialnumber </li>

<li><b>SPOT_ETODAY / etoday</b>             :  Today yield </li>

<li><b>SPOT_ETOTAL / etotal</b>             :  Total yield </li>

<li><b>SPOT_FEEDTM / feed-in_time</b>       :  Feed-in time </li>

<li><b>SPOT_FREQ / grid_freq.</b>           :  Grid Frequency </li>

<li><b>SPOT_IAC1 / phase_1_iac</b>          :  Grid current phase L1 </li>

<li><b>SPOT_IAC2 / phase_2_iac</b>          :  Grid current phase L2 </li>

<li><b>SPOT_IAC3 / phase_3_iac</b>          :  Grid current phase L3 </li>

<li><b>SPOT_IDC1 / string_1_idc</b>         :  DC current input </li>

<li><b>SPOT_IDC2 / string_2_idc</b>         :  DC current input </li>

<li><b>SPOT_OPERTM / operation_time</b>     :  Operation Time </li>

<li><b>SPOT_PAC1 / phase_1_pac</b>          :  Power L1  </li>

<li><b>SPOT_PAC2 / phase_2_pac</b>          :  Power L2  </li>

<li><b>SPOT_PAC3 / phase_3_pac</b>          :  Power L3  </li>

<li><b>SPOT_PACTOT / total_pac</b>          :  Total Power </li>

<li><b>SPOT_PDC1 / string_1_pdc</b>         :  DC power input 1 </li>

<li><b>SPOT_PDC2 / string_2_pdc</b>         :  DC power input 2 </li>

<li><b>SPOT_UAC1 / phase_1_uac</b>          :  Grid voltage phase L1 </li>

<li><b>SPOT_UAC2 / phase_2_uac</b>          :  Grid voltage phase L2 </li>

<li><b>SPOT_UAC3 / phase_3_uac</b>          :  Grid voltage phase L3 </li>

<li><b>SPOT_UDC1 / string_1_udc</b>         :  DC voltage input </li>

<li><b>SPOT_UDC2 / string_2_udc</b>         :  DC voltage input </li>

<li><b>SUSyID / susyid</b>                  :  Inverter SUSyID </li>

<li><b>INV_TEMP / device_temperature</b>    :  Inverter temperature </li>

<li><b>INV_TYPE / device_type</b>           :  Inverter Type </li>

<li><b>POWER_IN / power_in</b>              :  Battery Charging power </li>

<li><b>POWER_OUT / power_out</b>            :  Battery Discharging power </li>

<li><b>INV_GRIDRELAY / gridrelay_status</b> :  Grid Relay/Contactor Status </li>

<li><b>INV_STATUS / device_status</b>       :  Inverter Status </li>

<li><b>opertime_start</b>                   :  Begin of iverter operating time corresponding the calculated time of sunrise with consideration of the  

                                               attribute "offset" (if set) </li>

<li><b>opertime_stop</b>                    :  End of iverter operating time corresponding the calculated time of sunrise with consideration of the  

                                               attribute "offset" (if set) </li>

<li><b>modulstate</b>                       :  shows the current module state "normal" or "sleep" if the inverter won't be requested at the time. </li>

<li><b>avg_power_lastminutes_05</b>         :  average power of the last 5 minutes. </li>	

<li><b>avg_power_lastminutes_10</b>         :  average power of the last 10 minutes. </li>	

<li><b>avg_power_lastminutes_15</b>         :  average power of the last 15 minutes. </li>

<li><b>inverter_processing_time</b>         :  wasted time to retrieve the inverter data </li>

<li><b>background_processing_time</b>       :  total wasted time by background process (BlockingCall) </li>

</ul>

<br><br>

