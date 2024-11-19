import sys
import csv
import math
from collections import defaultdict

# 0 project, 1 profile, 2 bit, 3 codec, 4 crf, 5 psnr, 6 ssim, 7 vmaf, 8 size
operation = "codecByProfile"
# for all metric measurements
metricID = 5
metricInf = 60
# for oneCodec and codecByProfile
codecName = "vvc"
profileName = "ACES"

dualValue = False
getAverage = False
values = defaultdict(float)
valuesB = defaultdict(float)
valuesCounts = defaultdict(float)
with open(sys.argv[1], 'r') as f:
    csvreader = csv.reader(f)
    fields = next(csvreader)
    for row in csvreader:

        # Counts the measurements for each profile
        key = ""
        if operation == 'check':
            key = row[0]
            values[key] += 1

        # Calculates the average for each profile over all codecs
        elif operation == 'all':
            key = row[1]
            value = float(row[metricID])
            if math.isinf(value):
                value = metricInf
            values[key] += value
            valuesB[key] += float(row[8])
            dualValue = True
            getAverage = True

        # Calculates the average quality course chart for each profile and selected codec
        elif operation == 'oneCodec':
            if row[3].strip() == codecName and row[1].strip() == profileName:
                key = row[4]
                value = float(row[metricID])
                if math.isinf(value):
                    value = metricInf
                values[key] += value
                valuesB[key] += float(row[8])
            dualValue = True
            getAverage = True

        # Calculates the average of the whole codec (all quality levels grouped) for each profile
        elif operation == 'codecByProfile':
            if row[3].strip() == codecName:
                key = row[1]
                value = float(row[metricID])
                if math.isinf(value):
                    value = metricInf
                values[key] += value
                valuesB[key] += float(row[8])
            dualValue = True
            getAverage = True

        valuesCounts[key] += 1

for key in values:
    result = values[key]
    if getAverage:
        result = result / valuesCounts[key]
    print(key, result, end ="")
    if dualValue:
        result = valuesB[key]
        if getAverage:
            result = result / valuesCounts[key]
        print(", " + str(result))
    else:
        print("")
