# Path simplification tool (Visvalingam-Whyatt algorithm if I recall)
# Input is "PathGen.txt" containing a series of text lines containing space delineated coordinates (x="#" y="#" z="#") of points on the path
# Additional data on those lines is permitted but discarded (can handle raw xml output from LogParser), lines lacking those fields are likewise ignored
# Simplification is calculated on the x/y plane, removing 80% of the points (with a hard cap of 50 points if the input data was particularly long)
# Output is appended to the PathGen.txt file in a simple xml format suitable for use in Cartographer waypoint path data
import sys
import math

class Point:
	def __init__(self, x:int, y:int, z:int):
		self.x = x
		self.y = y
		self.z = z
		self.a = float("inf")
		
	def __eq__(self, other):
		return self.x == other.x and self.y == other.y and self.z == other.z
	
	def __add__(self, other):
		return Point(self.x + other.x, self.y + other.y, self.z + other.z)
	
	def __sub__(self, other):
		return Point(self.x - other.x, self.y - other.y, self.z - other.z)
		
	def __div__(self, scalar):
		return Point(self.x / scalar, self.y / scalar, self.z / scalar)
	
	def __truediv__(self, scalar):
		return Point(self.x / scalar, self.y / scalar, self.z / scalar)

	def __str__(self):
		return '<Point x="' + str(self.x) + '" y="' + str(self.y) + '" z="' + str(self.z) + '" />'

def CalcArea(target, prev, next):
	dp = prev - target
	dn = next - target
	target.a = abs(dp.x * dn.y - dp.y * dn.x) / 2
	
def GetMin(points):
	minA = float("inf")
	minI = -1
	for idx, pt in enumerate(points):
		if pt.a < minA:
			minA = pt.a
			minI = idx
		if minA == 0:
			return minI
	return minI
			
def LoopSimplify(points, isPoly, count):
	minI = GetMin(points)
	while len(points) > count or minI == 0:
		lp = len(points)		
		if isPoly:
			CalcArea(points[minI-1], points[minI-2], points[(minI+1)%lp])
			CalcArea(points[(minI+1)%lp], points[minI-1], points[(minI+2)%lp])
		else:
			if minI > 1:
				CalcArea(points[minI-1], points[minI-2], points[minI+1])
			if minI < lp - 2:
				CalcArea(points[minI+1], points[minI-1], points[minI+2])
		points.pop(minI)
		minI = GetMin(points)
	
def Simplify(points, count):
	isPoly = points[0] == points[-1]
	if isPoly:
		points.pop()
		CalcArea(points[0], points[-1], points[1])
		CalcArea(points[-1], points[-2], points[0])
	for idx, pt in enumerate(points[1:-1], start=1):
		CalcArea(pt, points[idx-1], points[idx+1])
	LoopSimplify(points, isPoly, count)
	if isPoly:
		points.append(points[0])
	
def Main(argv=None):
	if argv is None:
		argv = sys.argv
	try:
		points = []
		with open('.\PathGen.txt') as file:
			for line in file:
				x = None
				y = None
				z = None
				for entry in line.split(' '):
					if entry.startswith('x="'):
						x = int(entry.split('"')[1])
					if entry.startswith('y="'):
						y = int(entry.split('"')[1])
					if entry.startswith('z="'):
						z = int(entry.split('"')[1])
				if not (x is None or y is None or z is None):
					points.append(Point(x, y, z))
		Simplify(points, min(50, len(points) / 5))
		with open('.\PathGen.txt', 'a+') as file:
			file.write('\n')
			for p in points:
				file.write('\n' + str(p))
	except Exception as e:
		print(e)
		return 1
		
if __name__ == '__main__':
	sys.exit(Main())
