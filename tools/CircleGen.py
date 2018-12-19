# Minimal enclosing circle tool (Welzl's algorithm if I recall)
# Input is "CircleGen.txt" containing a series of text lines containing space delineated coordinates (x="#" y="#" z="#") of points inside the circle
# Additional data on those lines is permitted but discarded (can handle raw xml output from LogParser), lines lacking those fields are likewise ignored
# Circle is calculated on the x/y plane, with the z position calculated with a simple midpoint of the extremes. Duplicate data points may cause issues. Datasets are expected to be small enough that worst case processing time should be trivial, so it does not implement random input sequencing.
# Output is appended to the CircleGen.txt file in a simple xml format suitable for use in Cartographer waypoint area data
import sys
import math

class Point:
	def __init__(self, x:int, y:int):
		self.x = x;
		self.y = y;
	
	def __add__(self, other):
		return Point(self.x + other.x, self.y + other.y)
	
	def __sub__(self, other):
		return Point(self.x - other.x, self.y - other.y)
		
	def __div__(self, scalar:int):
		return Point(self.x / scalar, self.y / scalar)
	
	def __truediv__(self, scalar:int):
		return Point(self.x / scalar, self.y / scalar)
	
	def distSq(self, other):
		dif = self - other
		return dif.x * dif.x + dif.y * dif.y
	
class Circle:
	def __init__(self, ctr, rad):
		self.ctr = ctr
		self.rad = rad
	
	def contains(self, other):
		return self.ctr.distSq(other) <= self.rad * self.rad
		
	def __str__(self):
		return '<Circle type="area" x="' + str(self.ctr.x) + '" y="' + str(self.ctr.y) + '" radius="' + str(self.rad) + '" />'

def calcCircle2(p1, p2):
	ctr = (p1 + p2) / 2
	rad = math.sqrt(ctr.distSq(p1))
	return Circle(ctr, rad)
	
def calcCircle3(p1, p2, p3):
	p2d = p2 - p1
	p3d = p3 - p1
	
	p2e = (p2d.x * (p1.x + p2.x) + p2d.y * (p1.y + p2.y)) / 2
	p3e = (p3d.x * (p1.x + p3.x) + p3d.y * (p1.y + p3.y)) / 2
	det = p2d.x * p3d.y - p2d.y * p3d.x
	if det != 0:
		cx = (p3d.y * p2e - p2d.y * p3e) / det
		cy = (p2d.x * p3e - p3d.x * p2e) / det
		ctr = Point(cx, cy)
		rad = math.sqrt(ctr.distSq(p1))
		return Circle(ctr, rad)
	# Duplicated point (slight possibility that p2 and p3 are at a perfect right angle?)
	if (p1.distSq(p2) == 0):
		if (p1.distSq(p3) == 0):
			return Circle(p1, 0)
		return calcCircle2(p1, p3)
	return calcCircle2(p1, p2)
			
def mec(points, pCount, bounds):
	result = None
	
	if len(bounds) == 3:
		return calcCircle3(bounds[0], bounds[1], bounds[2])
	if pCount == 1 and len(bounds) == 0:
		return Circle(points[0], 0)
	if pCount == 1 and len(bounds) == 1:
		return calcCircle2(bounds[0], points[0])
	if pCount == 0 and len(bounds) == 2:
		return calcCircle2(bounds[0], bounds[1])

	result = mec(points, pCount - 1, bounds[:])
	if not result.contains(points[pCount -1]):
		bounds.append(points[pCount - 1])
		result = mec(points, pCount -1, bounds[:])
	
	return result
		
def Main(argv=None):
	if argv is None:
		argv = sys.argv
	try:
		points = []
		zlo = float('inf')
		zhi = -zlo
		with open('.\CircleGen.txt') as file:
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
				if not (x is None or y is None):
					points.append(Point(x, y))
				if not (z is None):
					zlo = min(zlo, z)
					zhi = max(zhi, z)
		circle = mec(points, len(points), [])
		with open('.\CircleGen.txt', 'a+') as file:
			file.write('\n' + str(circle) + ' z="' + str((zhi - zlo) / 2 + zlo)  + '"')
	except Exception as e:
		print(e)
		return 1
		
if __name__ == '__main__':
	sys.exit(Main())
