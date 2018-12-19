import sys
import os.path

def Main(argv=None):
    if argv is None:
        argv = sys.argv
    try:
        lines = []
        with open('..\..\..\..\..\ClientLog.txt', 'r') as logFile:
            newLines = [line.split(' - ', 1)[1] for line in logFile if '.TDD' in line]
            lines.extend(newLines)
        with open('.\DataDump.txt', 'a+') as outFile:
            outFile.writelines(lines)
    except Exception as e:
        print(e)
        return 1

if __name__ == '__main__':
    sys.exit(Main())

