@echo off
set outfile=..\reload.xml
echo ^<code^> > %outfile%
echo ^<![CDATA[ >> %outfile%
type ai\AIDriveStrategyCourse.lua >> %outfile%
type ai\AIDriveStrategyFieldWorkCourse.lua >> %outfile%
type ai\AIDriveStrategyCombineCourse.lua >> %outfile%
type ai\AIDriveStrategyPlowCourse.lua >> %outfile%
type ai\AIDriveStrategyBalerCourse.lua >> %outfile%
echo ]]^> >> %outfile%
echo ^</code^> >> %outfile%