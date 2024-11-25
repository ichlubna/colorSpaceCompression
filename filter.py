import sys
import csv
import math
from collections import defaultdict
from paretoset import paretoset
import pandas


#Data format: 0 project, 1 profile, 2 bit, 3 codec, 4 crf, 5 psnr, 6 ssim, 7 vmaf, 8 size
operation = "bit"
# for all metric measurements
metricID = 5
metricInf = 60.0
# for oneCodec and codecByProfile
codecName = "xvc"
profileName = "ProTune_Log"

pareto = False
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
            pareto = True
        
        # Calculates the average for each bit depth
        elif operation == 'bit':
            key = row[2]
            if row[3] != "libwebp" and row[3] != "libjxl":
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
            pareto = True

        valuesCounts[key] += 1


quality = []
size = []
names = []
for key in values:
    result = values[key]
    if getAverage:
        result = result / valuesCounts[key]
    names.append(key)
    quality.append(result)
    print(key, result, end ="")
    if dualValue:
        result = valuesB[key]
        if getAverage:
            result = result / valuesCounts[key]
        size.append(result)
        print(", " + str(result/1000000))
    else:
        print("")

if pareto:
    data = pandas.DataFrame({"quality": quality, "size": size})
    mask = paretoset(data, sense=["max", "min"])
    print("pareto")
    for i in range(len(mask)):
        #print(str(names[i])+" "+str(quality[i])+" "+str(size[i]/1000000)+" "+str(int(mask[i])))
        #print(str(int(mask[i])))
        #print(str(size[i]/1000000))
        #print(str(quality[i]))
        if int(mask[i]) == 1:
            print(str(names[i]))

