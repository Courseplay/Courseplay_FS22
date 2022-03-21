lu = require("luaunit")
package.path = package.path .. ";../?.lua;../util/?.lua"
require('mock-GiantsEngine')
require('mock-Courseplay')
require('CpObject')
require('CpUtil')
require('CpMathUtil')

------------------------------------------------------------------------------------------------------------------------
-- getSeries()
------------------------------------------------------------------------------------------------------------------------
local s = CpMathUtil.getSeries(1, 10, 1)
lu.assertItemsEquals(s, {1, 2, 3, 4, 5, 6, 7, 8, 9, 10})
s = CpMathUtil.getSeries(0, 10, 1)
lu.assertItemsEquals(s, {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10})
s = CpMathUtil.getSeries(1, 10, 2)
lu.assertItemsEquals(s, {1, 3.25, 5.5, 7.75, 10})
s = CpMathUtil.getSeries(-10, 10, 2)
lu.assertItemsEquals(s, {-10, -8, -6, -4, -2, 0, 2, 4, 6, 8, 10})
s = CpMathUtil.getSeries(10, 1, 2)
lu.assertItemsEquals(s, {10, 7.75, 5.5, 3.25, 1})
s = CpMathUtil.getSeries(1, 10, 10)
lu.assertItemsEquals(s, {1, 10})
s = CpMathUtil.getSeries(1, 10, 100)
lu.assertItemsEquals(s, {1, 10})
s = CpMathUtil.getSeries(10, 1, 100)
lu.assertItemsEquals(s, {1, 10})

s = CpMathUtil.getSeries(0, 10.5, 1)
-- assertItemsEquals does not work with that 3.15 for whatever reason, so assert them one by one
lu.almostEquals(s[4], 0, 0.001)
lu.almostEquals(s[4], 1.05, 0.001)
lu.almostEquals(s[4], 2.1, 0.001)
lu.almostEquals(s[4], 4.2, 0.001)
lu.almostEquals(s[4], 5.25, 0.001)
lu.almostEquals(s[4], 6.3, 0.001)
lu.almostEquals(s[4], 7.35, 0.001)
lu.almostEquals(s[4], 8.4, 0.001)
lu.almostEquals(s[4], 9.45, 0.001)
lu.almostEquals(s[4], 10.5, 0.001)

------------------------------------------------------------------------------------------------------------------------
-- isPointInPolygon()
------------------------------------------------------------------------------------------------------------------------
local polygon = {
    {x = -10, z = -10},
    {x = 10, z = -10},
    {x = 10, z = 10},
    {x = -10, z = 10},
}
lu.assertIsTrue(CpMathUtil.isPointInPolygon(polygon, 0, 0))
lu.assertIsTrue(CpMathUtil.isPointInPolygon(polygon, 5, 5))
lu.assertIsTrue(CpMathUtil.isPointInPolygon(polygon, -5, -5))
lu.assertIsTrue(CpMathUtil.isPointInPolygon(polygon, -10, -5))
lu.assertIsTrue(CpMathUtil.isPointInPolygon(polygon, -10, 10))

lu.assertIsFalse(CpMathUtil.isPointInPolygon(polygon, -10.01, -5))
lu.assertIsFalse(CpMathUtil.isPointInPolygon(polygon, 10.01, 50))

polygon = {
    {x = -10, z = -10},
    {x = 10, z = -10},
    {x = 0, z = 0},
    {x = 10, z = 10},
    {x = -10, z = 10},
}

lu.assertIsTrue(CpMathUtil.isPointInPolygon(polygon, 0, 0))
lu.assertIsTrue(CpMathUtil.isPointInPolygon(polygon, 5, 5))
lu.assertIsTrue(CpMathUtil.isPointInPolygon(polygon, -5, -5))
lu.assertIsTrue(CpMathUtil.isPointInPolygon(polygon, -10, -5))
lu.assertIsTrue(CpMathUtil.isPointInPolygon(polygon, -10, 10))

lu.assertIsFalse(CpMathUtil.isPointInPolygon(polygon, 0.01, 0))
lu.assertIsFalse(CpMathUtil.isPointInPolygon(polygon, 10, 0))
lu.assertIsFalse(CpMathUtil.isPointInPolygon(polygon, 5, 2))
lu.assertIsFalse(CpMathUtil.isPointInPolygon(polygon, 5, -2))
lu.assertIsFalse(CpMathUtil.isPointInPolygon(polygon, -10.01, -5))
lu.assertIsFalse(CpMathUtil.isPointInPolygon(polygon, 10.01, 50))

------------------------------------------------------------------------------------------------------------------------
-- getAreaOfPolygon()
------------------------------------------------------------------------------------------------------------------------
local z1 = 0
polygon = {
    {x = -10, z = z1 -10},
    {x = 10, z = z1 - 10},
    {x = 10, z = z1 + 10},
    {x = -10, z = z1 + 10},
}

lu.assertAlmostEquals(CpMathUtil.getAreaOfPolygon(polygon), 400)
z1 = 10
lu.assertAlmostEquals(CpMathUtil.getAreaOfPolygon(polygon), 400)
z1 = 5000
lu.assertAlmostEquals(CpMathUtil.getAreaOfPolygon(polygon), 400)
z1 = -5000
lu.assertAlmostEquals(CpMathUtil.getAreaOfPolygon(polygon), 400)

z1 = 0
polygon = {
    {x = -10, z = z1 -10},
    {x = 10, z = z1 - 10},
    {x = 0, z = z1 + 0},
    {x = 10, z = z1 + 10},
    {x = -10, z = z1 + 10},
}
lu.assertAlmostEquals(CpMathUtil.getAreaOfPolygon(polygon), 300)
z1 = 5000
lu.assertAlmostEquals(CpMathUtil.getAreaOfPolygon(polygon), 300)
z1 = -5000
lu.assertAlmostEquals(CpMathUtil.getAreaOfPolygon(polygon), 300)

-- the other way round
z1 = 0
polygon = {
    {x = -10, z = z1 + 10},
    {x = 10, z = z1 + 10},
    {x = 10, z = z1 - 10},
    {x = -10, z = z1 -10},
}
lu.assertAlmostEquals(CpMathUtil.getAreaOfPolygon(polygon), 400)

-- with y
z1 = 0
polygon = {
    {x = -10, y = 100, z = z1 + 10},
    {x =  10, y = 100, z = z1 + 10},
    {x =  10, y = 100, z = z1 - 10},
    {x = -10, y = 100, z = z1 -10},
}
lu.assertAlmostEquals(CpMathUtil.getAreaOfPolygon(polygon), 400)

-- with y ony
z1 = 0
polygon = {
    {x = -10, y = z1 + 10},
    {x =  10, y = z1 + 10},
    {x =  10, y = z1 - 10},
    {x = -10, y = z1 -10},
}
lu.assertAlmostEquals(CpMathUtil.getAreaOfPolygon(polygon), 400)


polygon = {
    {x = -10, z = z1 + 10},
    {x = 10, z = z1 + 10},
    {x = 0, z = z1 + 0},
    {x = 10, z = z1 - 10},
    {x = -10, z = z1 -10},
}
lu.assertAlmostEquals(CpMathUtil.getAreaOfPolygon(polygon), 300)

polygon = {
    {x = 653.48, z = -76.97},
    {x = 653.48, z = -76.97},
    {x = 653.48, z = -76.97},
    {x = 654.62, z = -72.11},
    {x = 655.77, z = -67.24},
    {x = 656.91, z = -62.37},
    {x = 658.05, z = -57.50},
    {x = 659.19, z = -52.63},
    {x = 660.33, z = -47.76},
    {x = 661.47, z = -42.90},
    {x = 662.61, z = -38.03},
    {x = 663.75, z = -33.16},
    {x = 665.19, z = -27.04},
    {x = 665.19, z = -27.04},
    {x = 665.19, z = -27.04},
    {x = 669.66, z = -24.81},
    {x = 672.99, z = -23.14},
    {x = 672.99, z = -23.14},
    {x = 672.99, z = -23.14},
    {x = 677.99, z = -23.25},
    {x = 682.99, z = -23.36},
    {x = 690.54, z = -23.53},
    {x = 690.54, z = -23.53},
    {x = 690.54, z = -23.53},
    {x = 694.89, z = -26.00},
    {x = 699.24, z = -28.47},
    {x = 703.58, z = -30.94},
    {x = 707.93, z = -33.41},
    {x = 712.28, z = -35.88},
    {x = 716.63, z = -38.35},
    {x = 720.97, z = -40.82},
    {x = 725.32, z = -43.29},
    {x = 729.67, z = -45.76},
    {x = 734.02, z = -48.23},
    {x = 738.36, z = -50.70},
    {x = 742.03, z = -52.79},
    {x = 742.03, z = -52.79},
    {x = 742.03, z = -52.79},
    {x = 746.60, z = -54.82},
    {x = 751.17, z = -56.86},
    {x = 755.73, z = -58.90},
    {x = 760.30, z = -60.93},
    {x = 764.87, z = -62.97},
    {x = 770.90, z = -65.66},
    {x = 770.90, z = -65.66},
    {x = 770.90, z = -65.66},
    {x = 770.40, z = -70.64},
    {x = 769.91, z = -75.61},
    {x = 769.41, z = -80.59},
    {x = 768.91, z = -85.56},
    {x = 768.41, z = -90.54},
    {x = 767.92, z = -95.51},
    {x = 767.42, z = -100.49},
    {x = 766.92, z = -105.46},
    {x = 766.42, z = -110.44},
    {x = 765.93, z = -115.41},
    {x = 765.43, z = -120.39},
    {x = 764.66, z = -128.08},
    {x = 764.66, z = -128.08},
    {x = 764.66, z = -128.08},
    {x = 759.67, z = -128.44},
    {x = 754.69, z = -128.81},
    {x = 749.70, z = -129.18},
    {x = 744.71, z = -129.54},
    {x = 739.73, z = -129.91},
    {x = 734.74, z = -130.28},
    {x = 729.75, z = -130.64},
    {x = 724.77, z = -131.01},
    {x = 719.78, z = -131.38},
    {x = 714.80, z = -131.74},
    {x = 711.61, z = -131.98},
    {x = 711.61, z = -131.98},
    {x = 711.61, z = -131.98},
    {x = 707.09, z = -129.84},
    {x = 702.57, z = -127.70},
    {x = 698.05, z = -125.56},
    {x = 693.53, z = -123.42},
    {x = 689.01, z = -121.28},
    {x = 684.49, z = -119.14},
    {x = 679.97, z = -117.00},
    {x = 675.45, z = -114.87},
    {x = 670.93, z = -112.73},
    {x = 666.41, z = -110.59},
    {x = 660.51, z = -107.79},
    {x = 660.51, z = -107.79},
    {x = 660.51, z = -107.79},
    {x = 659.12, z = -102.99},
    {x = 657.74, z = -98.18},
    {x = 656.36, z = -93.38},
    {x = 654.97, z = -88.57},
    {x = 653.09, z = -82.04},
    {x = 653.09, z = -82.04},
}
lu.assertAlmostEquals(CpMathUtil.getAreaOfPolygon(polygon), 9444.2532)
