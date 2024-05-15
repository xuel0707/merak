import os
import sys

beforeVector = {}
afterVector = {}

def lineProcess(str):
    retstr = ''
    strlist = str.split(' ')
    for ele in strlist:
        retstr = retstr + ele
    if retstr[-1] == '{' or retstr[-1] == '(':
        retstr = retstr[:-1]
    return retstr

def p4fileTagRecord(f):
    beforeLine = ''
    afterLine = ''
    tagVlaue = ''

    line = f.readline()
    while line:
        if "#ifdef" in line: 
            tagValue = line
            line = f.readline()
            while not line.strip():
                checkFile.write(line)
                line = f.readline()
            if "#endif" in line: 
                tagVlaue = ''
                line = f.readline()
                continue
            beforeVector[lineProcess(line)] = tagValue
            tagVlaue = ''
        elif "#endif" in line: 
            tagVlaue = line
            line = f.readline()
            while not line.strip():
                checkFile.write(line)
                line = f.readline()
            if "ifdef" in line: 
                tagVlaue = tagVlaue + line
                line = f.readline()
                while not line.strip():
                    checkFile.write(line)
                    line = f.readline()
            elif '}' in line:
                tagVlaue = tagVlaue + line
                checkFile.write(line)
                line = f.readline()
                while not line.strip():
                    checkFile.write(line)
                    line = f.readline()
                if "ifdef" in line:
                    tagVlaue = tagVlaue + line
                    line = f.readline()
                    while not line.strip():
                        checkFile.write(line)
                        line = f.readline()
            beforeVector[lineProcess(line)] = tagVlaue
            tagVlaue = ''
        else :
            if line.strip():
                beforeLine = line;
        checkFile.write(line)
        line = f.readline()
    print(beforeVector)

def p4fileRecover(path,file):
    fp = open(os.path.join(path, 'finish_' + file), 'rt')
    fw = open(os.path.join(path, 'pp_' + file), 'wt')
    line = fp.readline()
    while line:
        if '}' in line:
            lineStr = line
            line = fp.readline()
            while not line.strip():
                lineStr = lineStr + line
                line = fp.readline()
            if lineProcess(line) in beforeVector.keys() and '#endif\n}' in beforeVector[lineProcess(line)]:
                fw.write(beforeVector[lineProcess(line)])
                fw.write(line)
                line = fp.readline()
                continue
            else :
                fw.write(lineStr)
        if lineProcess(line) in beforeVector.keys():
            fw.write(beforeVector[lineProcess(line)])
            fw.write(line)
        elif lineProcess(line) in afterVector.keys():
            fw.write(line)
            fw.write(afterVector[lineProcess(line)])
        else:
            fw.write(line)
        line = fp.readline()
    fw.close()
    fp.close()
    cmd = 'rm ' + os.path.join(path, 'finish_' + file)
    os.system(cmd)


def p4fileCheck(path,file):
    f = open(os.path.join(path, file), 'rt')
    global checkFile
    checkFile = open(os.path.join(path, 'check_' + file), 'wt')
    p4fileTagRecord(f)
    f.close()
    checkFile.close()
    cmd = 'p4test ' + os.path.join(path,'check_' + file) + ' --pp ' + os.path.join(path,'finish_' + file)
    #ret = os.system(cmd)
    fcmd = os.popen(cmd)
    if fcmd.read():
        print(fcmd.read())
        return
    p4fileRecover(path,file)
    cmd = 'rm ' + os.path.join(path, 'check_' + file)
    os.system(cmd)



# if __name__ == '__main__':
#     file = sys.argv[1]
#     p4trans(file)


