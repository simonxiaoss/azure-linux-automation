﻿Import-Module .\TestLibs\RDFELibs.psm1 -Force
$testResult = ""
$result = ""
$resultArr = @()
$isDeployed = DeployVMS -setupType $currentTestData.setupType -Distro $Distro -xmlConfig $xmlConfig
if ($isDeployed)
{
	foreach ($VMdata in $allVMData)
	{
		if ($VMdata.RoleName -imatch $currentTestData.setupType)
		{
			$hs1VIP = $VMdata.PublicIP
			$hs1vm1sshport = $VMdata.SSHPort
			$hs1vm1tcpport = $VMdata.TCPtestPort
			$hs1vm1udpport = $VMdata.UDPtestPort
			$hs1ServiceUrl = $VMdata.URL
		}
		elseif ($VMdata.RoleName -imatch "DTAP")
		{
			$dtapServerIp = $VMdata.PublicIP
			$dtapServerSshport = $VMdata.SSHPort
			$dtapServerTcpport = $VMdata.TCPtestPort
			$dtapServerUdpport = $VMdata.UDPtestPort
		}
	}
	LogMsg "Test Machine : $hs1VIP : $hs1vm1sshport"
	LogMsg "DTAP Machine : $dtapServerIp : $hs1vm1sshport"
	$iperfTimeoutSeconds = $currentTestData.iperfTimeoutSeconds

	$server = CreateIperfNode -nodeIp $hs1VIP -nodeSshPort $hs1vm1sshport -nodeUdpPort $dtapServerUdpport -nodeIperfCmd $cmd1 -user $user -password $password -files $currentTestData.files -logDir $LogDir
	$client = CreateIperfNode -nodeIp $dtapServerIp  -nodeSshPort $dtapServerSshport -nodeudpPort $hs1vm1udpport -nodeIperfCmd $cmd2 -user $user -password $password -files $currentTestData.files -logDir $LogDir

	foreach ($mode in $currentTestData.TestMode.Split(","))
	{
		try
		{
			$testResult = $null
			LogMsg "Test Started in $mode mode.."
			mkdir $LogDir\$mode -ErrorAction SilentlyContinue | out-null

			$server.cmd ="$python_cmd start-server.py -i1 -p $hs1vm1udpport -u yes && mv Runtime.log start-server.py.log -f"

			if(($mode -eq "IP") -or ($mode -eq "VIP") -or ($mode -eq "DIP"))
			{
				$client.cmd ="$python_cmd start-client.py -c $hs1VIP -i1 -p $hs1vm1udpport -t$iperfTimeoutSeconds -u yes -l 1420"
			}

			if(($mode -eq "URL") -or ($mode -eq "Hostname"))
			{
				$client.cmd ="$python_cmd start-client.py -c $hs1ServiceUrl -i1 -p $hs1vm1udpport -t$iperfTimeoutSeconds -u yes -l 1420"
			}
			$server.logDir = "$LogDir\$mode"
			$client.logDir = "$LogDir\$mode"
			$testResult =IperfClientServerUDPTest -server $server -client $client
			LogMsg "$($currentTestData.testName) : $mode : $testResult"
		}
		catch
		{
			$ErrorMessage =  $_.Exception.Message
			LogMsg "EXCEPTION : $ErrorMessage"   
		}
		Finally
		{
			$metaData = $mode 
			if (!$testResult)
			{
				$testResult = "Aborted"
			}
			$resultArr += $testResult
			$resultSummary +=  CreateResultSummary -testResult $testResult -metaData $metaData -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName# if you want to publish all result then give here all test status possibilites. if you want just failed results, then give here just "FAIL". You can use any combination of PASS FAIL ABORTED and corresponding test results will be published!
		}
	}
}
else
{
	$testResult = "Aborted"
	$resultArr += $testResult
}

$result = GetFinalResultHeader -resultarr $resultArr

#Clean up the setup
DoTestCleanUp -result $result -testName $currentTestData.testName -deployedServices $isDeployed -ResourceGroups $isDeployed

#Return the result and summery to the test suite script..
return $result,$resultSummary
