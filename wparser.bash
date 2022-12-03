#!/bin/bash

# hashir khan 
# bsc
# hashir.khan@mail.mcgill.ca

#set -x

if [[ $# -ne 1 ]]
then
	echo "Usage: $0 <weatherdatadir>"
	exit 1
fi

if [[ ! -d $1 ]]
then 
	echo "Error! $1 is not a valid directory name" 1>&2
	exit 1
fi

# storing all files matching the expression in an array 
files=( $(find $1 -name 'weather_info_[0-9]*\.data') )


result=""
extractData() 
{
	local file=$1
	echo "Processing Data From ${file}"
	echo "===================================="
	echo "Year,Month,Day,Hour,TempS1,TempS2,TempS3,TempS4,TempS5,WindS1,WindS2,WindS3,WinDir"

	# looking for lines which match observation line (these are the relavent lines with data) using sed to remove the observation line and [data log flushed] messages
	local filtered1=$(grep 'observation\ line' ${file} | sed -e 's/observation\ line  //' -e 's/observation\ line \[data\ log\ flushed\]  //')

	# reformating the date with sed by using regular expression to match date type string like xxxx-xx-xx and replacing the '-' with ' '
	local filtered2=$(echo "${filtered1}" | sed -E 's/([0-9]{4})-([0-9]{2})-([0-9]{2}) ([0-9]{2}):..... /\1 \2 \3 \4 /g')
	
	# using an array with keys 0-7 and values N-NW to replace the windir number with the corresponding letter direction using awk
	local filtered3=$(echo "${filtered2}" | awk '
	BEGIN { dir["0"]="N"; dir["1"]="NE"; dir["2"]="E"; dir["3"]="SE"; dir["4"]="S"; dir["5"]="SW"; dir["6"]="W"; dir["7"]="NW" }
	{ $NF = dir[$NF]; print $0 }' | sed -e 's/MISSED\ SYNC\ STEP/NOINF/g')
	



	# replaces MISSED SYNC STEP and NOINF with most recent previous sensor data and formats text as csv (comma delimiter)
	# uses awk to keep an array of most recent previous sensor data (w/o NOINF/MISSED SYNC STEP) and reformats output	
	local filtered4=$(echo "${filtered3}" | awk '
        { for (i=1; i<=NF; i++)
                { if ($i != "NOINF")

                        cur_line[i]=$i;

                }

        }
        {for (key in cur_line) {printf("%s,", cur_line[key])} }
        {print ""}' | sed -E 's/,$//g')
	
	echo "${filtered4}"	
	echo "===================================="

	# part 5 now
	echo "Observation Summary"
	echo "Year,Month,Day,Hour,MaxTemp,MinTemp,MaxWS,MinWS"

	# loop over each relavent column and update the current max and min temps/WS and using sed to print as a csv
	local filtered5=$(echo "${filtered3}" | awk '
	{MaxTemp=-9999999999; MinTemp=9999999999; MaxWS=-9999999999; MinWS=9999999999}
	{ for (k=5; k<10; k++)
	        { if ($k == "NOINF")
	               continue
	        else
	                { if ($k > MaxTemp)
	                        MaxTemp=$k;
	                if ($k < MinTemp)
	                        MinTemp=$k;
	                }
	        }
	}
	{ for (m=10; m<13; m++)
	
	        { if ($m > MaxWS)
	                MaxWS=$m;
	        if ($m < MinWS)
	                MinWS=$m;
	        }
	}
	{ print $1, $2, $3, $4, MaxTemp, MinTemp, MaxWS, MinWS }'| sed -E 's/\ /,/g')
	echo "${filtered5}"

	echo "=================================="
	

	# part 6 now, counts number of NOINF (all MISSED SYNC STEP where changed to NOINF before by sed) and saves current temperature error data to result
        local cur_health=$(echo "${filtered3}" | awk -d '
        BEGIN { t1_err=0; t2_err=0; t3_err=0; t4_err=0; t5_err=0; errs=0 }
        /NOINF/ { if ($5 == "NOINF")
                        t1_err ++
                if ($6 == "NOINF")
                        t2_err ++
                if ($7 == "NOINF")
                        t3_err ++
                if ($8 == "NOINF")
                        t4_err ++
                if ($9 == "NOINF")
                        t5_err ++
                }
        { year=$1; month=$2; day=$3 }
 
        END { errs=t1_err + t2_err + t3_err +t4_err + t5_err; print year, month, day, t1_err, t2_err, t3_err, t4_err, t5_err, errs}
        ')
	
	# stores the sensor health data for each day/weatherdata file 
	result="${result}${cur_health}
"
}



# iterating over the files array to call extractData on each file  
for name in ${files[@]}
do
	extractData ${name}
done



# put all the html formatting stuff in a function to allow to redirect to a .html file 
htmldata()
{

echo "<HTML>"
echo "<BODY>"
echo "<H2>Sensor error statistics</H2>"
echo "<TABLE>"
echo "<TR><TH>Year</TH><TH>Month</TH><TH>Day</TH><TH>TempS1</TH><TH>TempS2</TH><TH>TempS3</TH><TH>TempS4</TH><TH>TempS5</TH><TH>Total</TH><TR>"


# combined data from each weather file and sorts it first by descending order for num of total errors then by ascending order of date
# formats data as html table by print odd columns with <TD> and even columns with </TD> at the end and using sed to format the start and end the <TR>
local sorted=$(echo "${result}" | sort -k9,9nr -k1,3n)
echo "${sorted}" | awk '
{ for (i=1; i<NF; i++)
        printf "%s<\/TD><TD>", $i;
printf "%s<\/TD>", $i;
}
{print ""}
' 2>/dev/null | sed -E -e 's/^/<TR><TD>/g' -e 's/$/<\/TR>/g'

echo "</TABLE>"
echo "</BODY>"
echo "</HTML>"

}

htmldata > sensorstats.html

