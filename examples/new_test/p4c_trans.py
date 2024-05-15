import os
import sys
import re
import enum
import file_trans

headerVectorFPGA = {}
headerVectorPPK = {}
headerVectorASIC = {}
headerVectorALL = {}

class Stage(enum.Enum):
    ALL = 0
    FPGA = 1
    PPK = 2
    ASIC = 3

stage = Stage.ALL
constValues = {Stage.FPGA:[],Stage.PPK:[],Stage.ASIC:[],Stage.ALL:[]}


def fileWrite(parseVec):
    global stage
    if stage == Stage.FPGA:
        if type(parseVec) == str:
            fpgaFile.write(parseVec)
            return
        for line in parseVec:
            fpgaFile.write(line)
    elif stage == Stage.PPK:
        if type(parseVec) == str:
            ppkFile.write(parseVec)
            return
        for line in parseVec:
            ppkFile.write(line)
    elif stage == Stage.ASIC:
        if type(parseVec) == str:
            asicFile.write(parseVec)
            return
        for line in parseVec:
            asicFile.write(line)
    else :
        if type(parseVec) == str:
            fpgaFile.write(parseVec)
            ppkFile.write(parseVec)
            asicFile.write(parseVec)
            return
        for line in parseVec:
            fpgaFile.write(line)
            ppkFile.write(line)
            asicFile.write(line)


def p4HeaderDistinct(parseVec):
    headerInfo = {}
    index = 0
    global stage
    line = parseVec[index]
    if "header" in line:
        typeName = re.match('(@controller.*?|)\s*header\s+([a-zA-Z0-9_]+)', line)
        if typeName:
            headerName = typeName.group(2)
            #print(typeName.group(1))
    else :
        print('error in p4HeaderDistinct')
    index = index + 1

    while index < len(parseVec):
        line = parseVec[index]
        eleInfo = re.match('\s*([a-zA-Z0-9_\<\>]+)\s+([a-zA-Z0-9_]+)', line)
        if eleInfo:
            eleType = eleInfo.group(1)
            eleName = eleInfo.group(2)
            headerInfo[eleName] = eleType
            #print(eleInfo.group(1),eleInfo.group(2))
        index = index + 1

    if stage == Stage.FPGA:
        headerVectorFPGA[headerName] = headerInfo
    elif stage == Stage.PPK:
        headerVectorPPK[headerName] = headerInfo
    elif stage == Stage.ASIC:
        headerVectorASIC[headerName] = headerInfo
    else :
        headerVectorALL[headerName] = headerInfo
    fileWrite(parseVec)
 

def p4StructDistinct(parseVec):
    index = 0
    global stage
    line = parseVec[index]
    if "struct" in line:
        typeName = re.match('\s*struct\s+([a-zA-Z0-9_]+)', line)
        if typeName:
            structName = typeName.group(1)
            #print(typeName.group(1))
    else :
        print('error in p4StructDistinct')
    fileWrite(line)
    index = index + 1

    headerVectorFPGA[structName] = {}
    headerVectorPPK[structName] = {}
    headerVectorASIC[structName] = {}
    headerVectorALL[structName] = {}

    for line in parseVec[index:]:
        if re.match('\/\/', line.strip()):
            continue
        if "#ifdef" in line: 
            if stage != Stage.ALL:
                print(stage, " has been defined", line)
                return;
            if "UDEF_FPGA" in line:
                stage = Stage.FPGA
            elif "UDEF_PPK" in line:
                stage = Stage.PPK
            elif "UDEF_ASIC" in line:
                stage = Stage.ASIC
            continue
        elif "#endif" in line: 
            stage = Stage.ALL
            continue

        eleInfo = re.match('\s*([a-zA-Z0-9_\<\>]+)\s+([a-zA-Z0-9_]+)', line)
        if eleInfo:
            eleType = eleInfo.group(1)
            eleName = eleInfo.group(2)

            if eleType not in headerVectorFPGA.keys() and eleType not in headerVectorPPK.keys() and eleType not in headerVectorASIC.keys():
                if stage == Stage.FPGA:
                    headerVectorFPGA[structName][eleName] = eleType
                elif stage == Stage.PPK:
                    headerVectorPPK[structName][eleName] = eleType
                elif stage == Stage.ASIC:
                    headerVectorASIC[structName][eleName] = eleType
                else :
                    headerVectorALL[structName][eleName] = eleType
                fileWrite(line)
                continue

            if eleType in headerVectorFPGA.keys():
                if stage == Stage.FPGA or stage == Stage.ALL:
                    headerVectorFPGA[structName][eleName] = eleType
                    stageOld = stage
                    stage = Stage.FPGA
                    fileWrite(line)
                    stage = stageOld
                else:
                    print("p4StructDistinct error element in FPGA",eleType,eleName)
            if eleType in headerVectorPPK.keys():
                if stage == Stage.PPK or stage == Stage.ALL:
                    headerVectorPPK[structName][eleName] = eleType
                    stageOld = stage
                    stage = Stage.PPK
                    fileWrite(line)
                    stage = stageOld
                else:
                    print("p4StructDistinct error element in PPK",eleType,eleName)
            if eleType in headerVectorASIC.keys():
                if stage == Stage.ASIC or stage == Stage.ALL:
                    headerVectorASIC[structName][eleName] = eleType
                    stageOld = stage
                    stage = Stage.ASIC
                    fileWrite(line)
                    stage = stageOld
                else:
                    print("p4StructDistinct error element in ASIC",eleType,eleName)
        else:
            fileWrite(line)

    if len(headerVectorFPGA[structName].keys()) == 0:
        del headerVectorFPGA[structName]
    if len(headerVectorPPK[structName].keys()) == 0:
        del headerVectorPPK[structName]
    if len(headerVectorASIC[structName].keys()) == 0:
        del headerVectorASIC[structName]
    if len(headerVectorALL[structName].keys()) == 0:
        del headerVectorALL[structName]

def P4FindElement(arglist,arguments):
    if not type(arglist) == list:
        print("P4FindElement error ",arglist)
        return Stage.ALL
    if not arglist[0] in arguments.keys():
        if arglist[0] in constValues[Stage.FPGA]:
            return Stage.FPGA
        elif arglist[0] in constValues[Stage.PPK]:
            return Stage.PPK
        elif arglist[0] in constValues[Stage.ASIC]:
            return Stage.ASIC
        return Stage.ALL
    structName = arguments[arglist[0]]
    for i in range(1,len(arglist)):
        if structName in headerVectorALL.keys() and arglist[i] in headerVectorALL[structName]:
            structName = headerVectorALL[structName][arglist[i]]
            continue
        if structName in headerVectorFPGA.keys() and arglist[i] in headerVectorFPGA[structName]:
            return Stage.FPGA
        elif structName in headerVectorPPK.keys() and arglist[i] in headerVectorPPK[structName]:
            return Stage.PPK 
        elif structName in headerVectorASIC.keys() and arglist[i] in headerVectorASIC[structName]:
            return Stage.ASIC
        else :
            return Stage.ALL
    return Stage.ALL

def p4StateStage(arguments, stateDict,stateInfo):
    global stage
    for ele in stateDict.keys():
        for line in stateDict[ele]:
            if re.match('\/\/', line.strip()):
                continue
            if re.search("packet.extract", line):
                #print(line)
                arglist = re.search("\(([a-zA-Z0-9_\.]+)", line).group(1).split('.')
                stateInfo[ele] = P4FindElement(arglist, arguments)
            elif re.search("transition/s+select", line):
                arglist = re.search("\(([a-zA-Z0-9_\.]+)\)", line).group(1).split('.')
                stateInfo[ele] = P4FindElement(arglist, arguments)
            elif re.search("transition/s+accept",line):
                break
            if ele in stateInfo.keys():
                break



def p4StateParse(parseVec, arguments, stateInfo, stateDict):
    signdict = {"bracket":0, "parenthesis":0}
    index = 0
    while index < len(parseVec):
        stateVec = []
        line = parseVec[index]
        if re.search('state\s+([a-zA-Z0-9_]+)', line):
            stateName = re.search('state\s+([a-zA-Z0-9_]+)', line).group(1)
            while index < len(parseVec):
                line = parseVec[index]
                if re.search('\{', line):
                    signdict["bracket"] = signdict["bracket"] + len(re.search('\{', line).group())
                if re.search('\}', line):
                    signdict["bracket"] = signdict["bracket"] - len(re.search('\}', line).group())
                if re.search('\(', line):
                    signdict["parenthesis"] = signdict["parenthesis"] + len(re.search('\(', line).group())
                if re.search('\)', line):
                    signdict["parenthesis"] = signdict["parenthesis"] - len(re.search('\)', line).group())
                stateVec.append(line)
                if signdict["bracket"] == 0 and signdict["parenthesis"] == 0:
                    break
                index = index + 1
            stateDict[stateName] = stateVec
        index = index + 1
    p4StateStage(arguments, stateDict, stateInfo)


def p4ParserDistinct(parseVec):
    index = 0
    stateInfo = {}
    stateDict = {}
    arguments = {}
    argustr = ''
    global stage
    while index < len(parseVec):
        line = parseVec[index]
        fileWrite(line)
        argustr = argustr + line.strip()
        if re.search('\)', parseVec[index]):
            break
        index = index + 1
    index = index + 1
    arglist = re.search('\(([a-zA-Z0-9_\,\s]+)\)', argustr).group(1).split(',')
    for arg in arglist:
        argInfo = re.search('([a-zA-Z0-9_]+)\s+([a-zA-Z0-9_]+)\s+([a-zA-Z0-9_]+)', arg)
        if not argInfo:
            continue
        eleType = argInfo.group(2)
        eleName = argInfo.group(3)
        arguments[eleName] = eleType

    p4StateParse(parseVec[index:], arguments, stateInfo, stateDict)

    while index < len(parseVec):
        line = parseVec[index]
        if re.search('state', line):
            stateName = re.search('state\s+([a-zA-Z0-9_]+)', line).group(1)
            if stateName in stateInfo.keys() and stateInfo[stateName] != Stage.ALL:
                stage = stateInfo[stateName]
                fileWrite(parseVec[index:index + len(stateDict[stateName])])
                stage = Stage.ALL
                index = index + len(stateDict[stateName])
                continue
            else : # distinc transaction
                for line in stateDict[stateName]:
                    if re.search('(state|packet.extract|transition)', line):
                        fileWrite(line)
                    elif ':' in line:
                        stageKey = Stage.ALL
                        for val in constValues[Stage.FPGA]:
                            if val in line.split(':')[0]:
                                stageKey = Stage.FPGA
                                break
                        for val in constValues[Stage.PPK]:
                            if val in line.split(':')[0]:
                                stageKey = Stage.PPK
                                break
                        for val in constValues[Stage.ASIC]:
                            if val in line.split(':')[0]:
                                stageKey = Stage.ASIC
                                break
                        transStateName = re.search('\s*\:\s*([a-zA-Z0-9_]+)', line).group(1)
                        if transStateName in stateInfo.keys():
                            stage = stateInfo[transStateName]
                            if stage == Stage.ALL:
                                stage = stageKey
                            elif stage != stageKey and stageKey != Stage.ALL:
                                print('Key and Parse use different stage',line,stage, stageKey)
                            fileWrite(line)
                            stage = Stage.ALL
                        else:
                            stage = stageKey
                            fileWrite(line)
                            stage = Stage.ALL
                    else:
                        fileWrite(line)
                index = index + len(stateDict[stateName])
                continue
        else :
            fileWrite(line)
        index = index + 1


def p4ActionParse(parseVec, arguments, stageInfo, actionDict,tableDict):
    global stage
    i = 0
    while i < len(parseVec):
        actionVec = []
        tableVec = []
        line = parseVec[i]
        if re.search('action\s+([a-zA-Z0-9_]+)', line):
            actionName = re.search('action\s+([a-zA-Z0-9_]+)', line).group(1)
            signdict = {"bracket":0, "parenthesis":0}
            while i < len(parseVec):
                line = parseVec[i]
                if re.search('\{', line):
                    signdict["bracket"] = signdict["bracket"] + len(re.search('\{', line).group())
                if re.search('\}', line):
                    signdict["bracket"] = signdict["bracket"] - len(re.search('\}', line).group())
                if re.search('\(', line):
                    signdict["parenthesis"] = signdict["parenthesis"] + len(re.search('\(', line).group())
                if re.search('\)', line):
                    signdict["parenthesis"] = signdict["parenthesis"] - len(re.search('\)', line).group())
                actionVec.append(line)
                if signdict["bracket"] == 0 and signdict["parenthesis"] == 0:
                    break
                i = i + 1
            actionDict[actionName] = actionVec
        elif re.search('table\s+([a-zA-Z0-9_]+)', line):
            tableName = re.search('table\s+([a-zA-Z0-9_]+)', line).group(1)
            signdict = {"bracket":0, "parenthesis":0}
            while i < len(parseVec):
                line = parseVec[i]
                if re.search('\{', line):
                    signdict["bracket"] = signdict["bracket"] + len(re.search('\{', line).group())
                if re.search('\}', line):
                    signdict["bracket"] = signdict["bracket"] - len(re.search('\}', line).group())
                if re.search('\(', line):
                    signdict["parenthesis"] = signdict["parenthesis"] + len(re.search('\(', line).group())
                if re.search('\)', line):
                    signdict["parenthesis"] = signdict["parenthesis"] - len(re.search('\)', line).group())
                tableVec.append(line)
                if signdict["bracket"] == 0 and signdict["parenthesis"] == 0:
                    break
                i = i + 1
            tableDict[tableName] = tableVec
        i = i + 1

    for actionName in actionDict.keys():
        i = 0
        actionStage = Stage.ALL
        while i < len(actionDict[actionName]):
            line = actionDict[actionName][i]
            if re.search("([a-zA-Z0-9_])\(", line):
                actionFuc = re.search("([a-zA-Z0-9_]+)\(", line).group(1)
                if actionFuc in stageInfo['actionFPGA']:
                    stageInfo['actionFPGA'].append(actionName)
                if actionFuc in stageInfo['actionPPK']:
                    stageInfo['actionPPK'].append(actionName)
                if actionFuc in stageInfo['actionASIC']:
                    stageInfo['actionASIC'].append(actionName)
            if not re.search('([a-zA-Z0-9_]+)\.([a-zA-Z0-9_]+)', line):
                i = i + 1
                continue
            for ele in re.findall('([a-zA-Z0-9_]+\.[a-zA-Z0-9_\.]+)', line):
                argNamelist = ele.split('.')
                actionStageTmp = P4FindElement(argNamelist,arguments)
                if actionStageTmp != Stage.ALL:
                    if actionStage == Stage.ALL:
                        actionStage = actionStageTmp
                    elif actionStage != actionStageTmp:
                        print("action has different stage seq", actionName, line)
            i = i + 1

        if actionStage == Stage.FPGA:
            stageInfo['actionFPGA'].append(actionName)
        elif actionStage == Stage.PPK:
            stageInfo['actionPPK'].append(actionName)
        elif actionStage == Stage.ASIC:
            stageInfo['actionASIC'].append(actionName)

    actionsFPGA = stageInfo['actionFPGA'].copy()
    actionsPPK = stageInfo['actionPPK'].copy()
    actionsASIC = stageInfo['actionASIC'].copy()
    for tableName in tableDict.keys():
        i = 0
        keystr = ''
        actionstr = ''
        tableStage = Stage.ALL
        actionsList = []
        while i < len(tableDict[tableName]):
            line = tableDict[tableName][i]
            if 'key' in line:
                while not re.search('\}', line):
                    if re.match('\/\/', line.strip()):
                        i = i + 1
                        continue
                    keystr = keystr + line.split('//')[0].strip()
                    i = i + 1
                    line = tableDict[tableName][i]
                keystr = keystr + line.strip()
                if not re.search('([a-zA-Z0-9_\.]+)\s*\:\s*([a-zA-Z0-9_\.]+)', keystr):
                    #stageInfo['tableALL'].append(tableName)
                    i = i + 1
                    continue
                keyNamelist = re.search('([a-zA-Z0-9_\.]+)\s*\:\s*([a-zA-Z0-9_\.]+)', keystr).group(1).split('.')
                tableStage = P4FindElement(keyNamelist,arguments)
            elif 'actions' in line:
                i = i + 1
                line = tableDict[tableName][i]
                while not re.search('\}', line):
                    if re.match('\/\/', line.strip()):
                        i = i + 1
                        continue
                    actionstr = actionstr + re.search('([a-zA-Z0-9_]+;)',line).group(1).strip()
                    #actionstr = actionstr + line.split('//')[0].strip()
                    i = i + 1
                    line = tableDict[tableName][i]
                #actionstr = actionstr + line.strip()
                actionsList = actionstr[:-1].split(';')
                for actionName in actionsList:
                    tableStageTmp = Stage.ALL
                    if actionName in actionsFPGA:
                        tableStageTmp = Stage.FPGA
                    elif actionName in actionsPPK:
                        tableStageTmp = Stage.PPK
                    elif actionName in actionsASIC:
                        tableStageTmp = Stage.ASIC

                    if tableStage != Stage.ALL:
                        if tableStageTmp != Stage.ALL and tableStage != tableStageTmp:
                            print("this table has other stage action", actionName, tableName,tableStage, tableStageTmp)
                    else :
                        tableStage = tableStageTmp

                #actionsList = re.search('\{([a-zA-Z0-9_\;]+)\}', actionstr).group(1).split(';')
            i = i + 1
        if tableStage == Stage.FPGA:
            stageInfo['actionFPGA'].extend(actionsList)
            stageInfo['tableFPGA'].append(tableName)
        elif tableStage == Stage.PPK:
            stageInfo['actionPPK'].extend(actionsList)
            stageInfo['tablePPK'].append(tableName)
        elif tableStage == Stage.ASIC:
            stageInfo['actionASIC'].extend(actionsList)
            stageInfo['tableASIC'].append(tableName)
        else :
            stageInfo['actionALL'].extend(actionsList)
            stageInfo['tableALL'].append(tableName)

    for actionName in actionDict.keys():
        if actionName not in stageInfo['actionFPGA'] and actionName not in stageInfo['actionPPK'] and actionName not in stageInfo['actionASIC']:
            stageInfo['actionALL'].append(actionName)

def p4ControlDistinct(parseVec):
    index = 0
    stageInfo = {'tableFPGA':[],'tablePPK':[],'tableASIC':[],'tableALL':[],'actionFPGA':[],'actionPPK':[],'actionASIC':[],'actionALL':[]}
    actionDict = {}
    tableDict = {}
    argustr = ''
    arguments = {}
    global stage
    while index < len(parseVec):
        line = parseVec[index]
        fileWrite(line)
        argustr = argustr + line.strip()
        if re.search('\)', parseVec[index]):
            break
        index = index + 1
    index = index + 1
    arglist = re.search('\(([a-zA-Z0-9_\s\,]+)\)', argustr).group(1).split(',')
    for arg in arglist:
        argInfo = re.search('([a-zA-Z0-9_]+)\s+([a-zA-Z0-9_]+)\s+([a-zA-Z0-9_]+)', arg)
        if argInfo:
            eleType = argInfo.group(2)
            eleName = argInfo.group(3)
            arguments[eleName] = eleType

    p4ActionParse(parseVec, arguments, stageInfo, actionDict, tableDict)
    while index < len(parseVec):
        line = parseVec[index]
        if re.search('action', line):
            actionName = re.search('action\s+([a-zA-Z0-9_]+)', line).group(1)
            if actionName in stageInfo['actionALL']: # distinc transaction
                for line in actionDict[actionName]:
                    if re.match('\/\/', line.strip()):
                        fileWrite(line)
                        continue
                    if re.search('action', line):
                        fileWrite(line)
                    elif re.search('[\=|\+|\-]]', line):
                        argnameList = re.search('([a-zA-Z0-9_]+)', line).group(1)
                        for argName in argnameList:
                            arglist = argName.split('.')
                            stage = P4FindElement(arglist,arguments)
                            fileWrite(line)
                            stage = Stage.ALL
                    else:
                        fileWrite(line)
                index = index + len(actionDict[actionName])
                continue
            if actionName in stageInfo['actionFPGA']:
                stage = Stage.FPGA
                fileWrite(actionDict[actionName])
                stage = Stage.ALL

            if actionName in stageInfo['actionPPK']:
                stage = Stage.PPK
                fileWrite(actionDict[actionName])
                stage = Stage.ALL

            if actionName in stageInfo['actionASIC']:
                stage = Stage.ASIC
                fileWrite(actionDict[actionName])
                stage = Stage.ALL
            index = index + len(actionDict[actionName])
            continue
        elif re.search('table', line):
            tableName = re.search('table\s+([a-zA-Z0-9_]+)', line).group(1)
            if tableName in stageInfo['tableFPGA']:
                stage = Stage.FPGA
                fileWrite(tableDict[tableName])
                stage = Stage.ALL
                index = index + len(tableDict[tableName])

            if tableName in stageInfo['tablePPK']:
                stage = Stage.PPK
                fileWrite(tableDict[tableName])
                stage = Stage.ALL
                index = index + len(tableDict[tableName])

            if tableName in stageInfo['tableASIC']:
                stage = Stage.ASIC
                fileWrite(tableDict[tableName])
                stage = Stage.ALL
                index = index + len(tableDict[tableName])

            if tableName in stageInfo['tableALL']:
                stage = Stage.ALL
                fileWrite(tableDict[tableName])
                index = index + len(tableDict[tableName])
            continue
        elif re.search('apply', line):
            signdict = {"bracket":0, "parenthesis":0}
            signifdict = {"bracket":0, "parenthesis":0}
            ifTag = {Stage.FPGA:0,Stage.PPK:0,Stage.ASIC:0,Stage.ALL:0}
            while index < len(parseVec):
                if signifdict["bracket"] == 0 and signifdict["parenthesis"] == 0: 
                    ifTag = {Stage.FPGA:0,Stage.PPK:0,Stage.ASIC:0,Stage.ALL:0}
                line = parseVec[index]
                if re.match('\/\/', line.strip()):
                    fileWrite(line)
                    index = index + 1
                    continue
                if re.search('\{', line):
                    signdict["bracket"] = signdict["bracket"] + len(re.search('\{', line).group())
                if re.search('\}', line):
                    signdict["bracket"] = signdict["bracket"] - len(re.search('\}', line).group())

                if 'if' in line:
                    if re.search('if\s*\(([a-zA-Z0-9_\.]+)\.', line):
                        conditionNames = re.search('\(([a-zA-Z0-9_\.]+)', line).group(1).split('.')
                        stage = P4FindElement(conditionNames, arguments)
                        print(conditionNames,stage)
                        if stage == Stage.ALL and '==' in line:
                            conditionNames = re.search('([a-zA-Z0-9_\.]+)\)', line).group(1).split('.')
                            stage = P4FindElement(conditionNames, arguments)
                        if 'else' in line:
                            if ifTag[Stage.ALL] == 0 and stage == Stage.ALL:
                                replaceLine = line.replace('} else ','')
                                stage = Stage.FPGA
                                if ifTag[Stage.FPGA] != 0:
                                    fileWrite(line)
                                else :
                                    fileWrite(replaceLine)
                                stage = Stage.PPK
                                if ifTag[Stage.PPK] != 0:
                                    fileWrite(line)
                                else :
                                    fileWrite(replaceLine)
                                stage = Stage.ASIC
                                if ifTag[Stage.ASIC] != 0:
                                    fileWrite(line)
                                else :
                                    fileWrite(replaceLine)
                                stage = Stage.ALL
                            elif ifTag[stage] == 0 and ifTag[Stage.ALL] == 0:
                                line = line.replace('} else ','')
                                fileWrite(line)
                            else:
                                fileWrite(line)
                            #if re.search('\{', line):
                                #signifdict["bracket"] = signifdict["bracket"] + len(re.search('\{', line).group())
                            index = index + 1

                        ifTag[stage] = ifTag[stage] + 1
                    while index < len(parseVec):
                        line = parseVec[index]
                        if re.search('\{', line):
                            signifdict["bracket"] = signifdict["bracket"] + len(re.search('\{', line).group())
                        if re.search('\}', line):
                            signifdict["bracket"] = signifdict["bracket"] - len(re.search('\}', line).group())
                        if signifdict["bracket"] == 1 and 'else' in line:
                            break
                        fileWrite(line)
                        index = index + 1
                    continue
                elif 'else' in line:
                    stage = Stage.ALL
                    fileWrite(line)
                    index = index + 1
                    continue

                if 'packet.emit' in line:
                    arglist = re.search("\(([a-zA-Z0-9_\.\s]+)", line).group(1).strip().split('.')
                    stage = P4FindElement(arglist, arguments)

                if re.search("([a-zA-Z0-9_])\(", line):
                    actionApply = re.search("([a-zA-Z0-9_]+)\(", line).group(1)
                    if actionApply in stageInfo['actionFPGA']:
                        stage = Stage.FPGA
                    if actionApply in stageInfo['actionPPK']:
                        stage = Stage.PPK
                    if actionApply in stageInfo['actionASIC']:
                        stage = Stage.ASIC

                fileWrite(line)
                index = index + 1
                stage = Stage.ALL
                if signdict["bracket"] == 0 and signdict["parenthesis"] == 0:
                    break
        else :
            fileWrite(line)
            index = index + 1


def p4fileParser(f):
    signdict = {"bracket":0, "parenthesis":0}
    parseVec = []
    line = f.readline()
    global stage
    while line:
        if "#ifdef" in line: 
            if stage != Stage.ALL:
                print(stage, " has been defined", line)
                return;
            if "UDEF_FPGA" in line:
                stage = Stage.FPGA
            elif "UDEF_PPK" in line:
                stage = Stage.PPK
            elif "UDEF_ASIC" in line:
                stage = Stage.ASIC
        elif "#endif" in line: 
            stage = Stage.ALL
        elif re.match('(@controller.*?|)\s*(header|struct|parser|control)' ,line):
            p4TypeName = re.match('(@controller.*?|)\s*(header|struct|parser|control)' ,line).group(2)
            while  line:
                if re.search('\{', line):
                    signdict["bracket"] = signdict["bracket"] + len(re.search('\{', line).group())
                if re.search('\}', line):
                    signdict["bracket"] = signdict["bracket"] - len(re.search('\}', line).group())
                if re.search('\(', line):
                    signdict["parenthesis"] = signdict["parenthesis"] + len(re.search('\(', line).group())
                if re.search('\)', line):
                    signdict["parenthesis"] = signdict["parenthesis"] - len(re.search('\)', line).group())
                parseVec.append(line)
                if signdict["bracket"] == 0 and signdict["parenthesis"] == 0:
                    break
                line = f.readline()

            if p4TypeName == "header":
                #print("begin header parse")
                p4HeaderDistinct(parseVec)
            elif p4TypeName == "struct":
                #print("begin struct parse")
                p4StructDistinct(parseVec)
            elif p4TypeName == "parser":
                #print("begin parser parse")
                p4ParserDistinct(parseVec)
            elif p4TypeName == "control":
                #print("begin control parse")
                p4ControlDistinct(parseVec)

            parseVec=[]
        elif re.search('const.*?\s*([a-zA-Z0-9_])\s*\=' ,line):
            constName = re.search('const.*?\s*([a-zA-Z0-9_]+)\s*\=' ,line).group(1)
            if constName:
                constValues[stage].append(constName)
            fileWrite(line)
        else:
            fileWrite(line)

        line = f.readline()


def p4trans(path,file):
    f = open(os.path.join(path, file), 'rt')
    global fpgaFile
    fpgaFile = open(os.path.join(path, 'fpga' + (file[2:])), 'wt')
    global ppkFile
    ppkFile = open(os.path.join(path, 'ppk' + (file[2:])), 'wt')
    global asicFile
    asicFile = open(os.path.join(path, 'asic' + (file[2:])), 'wt')
    p4fileParser(f)
    f.close()
    fpgaFile.close()
    ppkFile.close()
    asicFile.close()



if __name__ == '__main__':
    file = sys.argv[1]
    path,filename = os.path.split(file)
    file_trans.p4fileCheck(path,filename)
    p4trans(path, 'pp_' + filename)
    cmd = 'rm ' + os.path.join(path, 'pp_' + filename)
    #os.system(cmd)


