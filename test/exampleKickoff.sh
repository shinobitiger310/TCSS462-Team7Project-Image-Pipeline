#!/bin/bash

# FaaS Runner Complex Experiment Example 
# @author Robert Cordingly

# Define Experiment Arguments
args=​"--function calcsServiceTutorial ​--runs 100 --threads 100 --warmupBuffer 0 --combineSheets 0 --sleepTime 0 --openCSV 0 --iterations 2 --memorySettings [256, 1024, 2048]"

# Create parent payload.
parentPayloadNoMemory=​"​{​\"​threads​\"​:2,​\"​sleep​\"​:0,​\"​loops​\"​:1000,​\"​arraySize​\"​:​1​}​" parentPayloadMemory=​"​{​\"​threads​\"​:2,​\"​sleep​\"​:0,​\"​loops​\"​:1000,​\"​arraySize​\"​:​1000000​}​"

# Generate scaling number of calcs payloads. 
#
# This creates a list of payloads like this:
# [{"calcs":1000},{"calcs":2000},...,{"calcs":99000},{"calcs":100000}] start=1000
step=1000
end=100000
payloads=​"​[​"
for​ ​calcs​ ​in​ ​$(​seq ​$start​ ​$step​ ​$end​) 
do
	payloads=​"​$payloads​{​\"​calcs​\"​:​$calcs​}​" ​
	if​ [ ​"​$calcs​"​ ​-lt​ ​"​$end​"​ ]
	​then
		payloads=​"​$payloads​,​" ​
	else
		payloads=​"​$payloads​]​" 
	​fi
done

# Created Payloads List:
echo​ ​"​Created Payloads List:​" 
echo ​$payloads

# Create Output Folders
mkdir complexExperiment
mkdir complexExperiment/NoMemory 
mkdir complexExperiment/Memory

# Run Experiments with and without Memory Stress
./faas_runner.py​ -o ./complexExperiment/NoMemory --payloads ​$payloads​ --parentPayload ​$parentPayloadNoMemory​ ​$args 
./faas_runner.py​ -o ./complexExperiment/Memory --payloads ​$payloads​ --parentPayload ​$parentPayloadMemory​ ​$args

echo​ ​"​Experiments Done!​"