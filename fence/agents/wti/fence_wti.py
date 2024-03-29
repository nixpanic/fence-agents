#!/usr/bin/python

#####
##
## The Following Agent Has Been Tested On:
##
##  Version            Firmware
## +-----------------+---------------------------+
##  WTI RSM-8R4         ?? unable to find out ??
##  WTI MPC-??? 	?? unable to find out ??
##  WTI IPS-800-CE     v1.40h		(no username) ('list' tested)
#####

import sys, re, pexpect, exceptions
sys.path.append("@FENCEAGENTSLIBDIR@")
from fencing import *

#BEGIN_VERSION_GENERATION
RELEASE_VERSION="New WTI Agent - test release on steroids"
REDHAT_COPYRIGHT=""
BUILD_DATE="March, 2008"
#END_VERSION_GENERATION

def get_power_status(conn, options):
	listing = ""

	conn.send("/S"+"\r\n")

	if isinstance(options["--command-prompt"], list):
		re_all = list(options["--command-prompt"])
	else:
		re_all = [options["--command-prompt"]]
	re_next = re.compile("Enter: ", re.IGNORECASE)
	re_all.append(re_next)

	result = conn.log_expect(options, re_all, int(options["--shell-timeout"]))
	listing = conn.before
	if result == (len(re_all) - 1):
		conn.send("\r\n")
		conn.log_expect(options, options["--command-prompt"], int(options["--shell-timeout"]))
		listing += conn.before
	
	plug_section = 0
	plug_index = -1
	name_index = -1
	status_index = -1
	plug_header = list()
	outlets = {}
	
	for line in listing.splitlines():
		if (plug_section == 2) and line.find("|") >= 0 and line.startswith("PLUG") == False:
			plug_line = [x.strip().lower() for x in line.split("|")]
			if len(plug_line) < len(plug_header):
				plug_section = -1
			if ["list", "monitor"].count(options["--action"]) == 0 and options["--plug"].lower() == plug_line[plug_index]:
				return plug_line[status_index]
			else:
				## We already believe that first column contains plug number
				if len(plug_line[0]) != 0:
					outlets[plug_line[0]] = (plug_line[name_index], plug_line[status_index])
		elif (plug_section == 1):
			plug_section = 2
		elif (line.upper().startswith("PLUG")):
			plug_section = 1
			plug_header = [x.strip().lower() for x in line.split("|")]
			plug_index = plug_header.index("plug")
			name_index = plug_header.index("name")
			status_index = plug_header.index("status")

	if ["list", "monitor"].count(options["--action"]) == 1:
		return outlets
	else:
		return "PROBLEM"

def set_power_status(conn, options):
	action = {
		'on' : "/on",
		'off': "/off"
	}[options["--action"]]

	conn.send(action + " " + options["--plug"] + ",y\r\n")
	conn.log_expect(options, options["--command-prompt"], int(options["--power-timeout"]))

def main():
	device_opt = [  "ipaddr", "login", "passwd", "no_login", "no_password", \
			"cmd_prompt", "secure", "port" ]

	atexit.register(atexit_handler)

	all_opt["cmd_prompt"]["default"] = [ "RSM>", "MPC>", "IPS>", "TPS>", "NBB>", "NPS>", "VMR>" ]

	options = check_input(device_opt, process_input(device_opt))

	docs = { }
	docs["shortdesc"] = "Fence agent for WTI"
	docs["longdesc"] = "fence_wti is an I/O Fencing agent \
which can be used with the WTI Network Power Switch (NPS). It logs \
into an NPS via telnet or ssh and boots a specified plug. \
Lengthy telnet connections to the NPS should be avoided while a GFS cluster \
is running because the connection will block any necessary fencing actions."
	docs["vendorurl"] = "http://www.wti.com"
	show_docs(options, docs)
	
	##
	## Operate the fencing device
	##
	## @note: if it possible that this device does not need either login, password or both of them
	#####	
	if 0 == options.has_key("--ssh"):
		try:
			try:
				conn = fspawn(options, TELNET_PATH)
				conn.send("set binary\n")
				conn.send("open %s -%s\n"%(options["--ip"], options["--ipport"]))
			except pexpect.ExceptionPexpect, ex:
				sys.stderr.write(str(ex) + "\n")
				sys.stderr.write("Due to limitations, binary dependencies on fence agents "
				"are not in the spec file and must be installed separately." + "\n")
				sys.exit(EC_GENERIC_ERROR)
			
			re_login = re.compile("(login: )|(Login Name:  )|(username: )|(User Name :)", re.IGNORECASE)
			re_prompt = re.compile("|".join(map (lambda x: "(" + x + ")", options["--command-prompt"])), re.IGNORECASE)

			result = conn.log_expect(options, [ re_login, "Password: ", re_prompt ], int(options["--shell-timeout"]))
			if result == 0:
				if options.has_key("--username"):
					conn.send(options["--username"]+"\r\n")
					result = conn.log_expect(options, [ re_login, "Password: ", re_prompt ], int(options["--shell-timeout"]))
				else:
					fail_usage("Failed: You have to set login name")
		
			if result == 1:
				if options.has_key("--password"):
					conn.send(options["--password"]+"\r\n")
					conn.log_expect(options, options["--command-prompt"], int(options["--shell-timeout"]))	
				else:
					fail_usage("Failed: You have to enter password or password script")
		except pexpect.EOF:
			fail(EC_LOGIN_DENIED) 
		except pexpect.TIMEOUT:
			fail(EC_LOGIN_DENIED)		
	else:
		conn = fence_login(options)

	result = fence_action(conn, options, set_power_status, get_power_status, get_power_status)

	##
	## Logout from system
	######
	try:
		conn.send("/X"+"\r\n")
		conn.close()
	except:
		pass
		
	sys.exit(result)

if __name__ == "__main__":
	main()
