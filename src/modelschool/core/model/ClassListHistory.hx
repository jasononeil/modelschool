package modelschool.core.model;

import ufront.db.Object;
import ufront.db.ManyToMany;
import sys.db.Types;

/**
	The `ClassListHistory` module contains models that keep a record of class lists and timemtables through time.

	- Each `TimetableSet` represents the full set of staff and student timetables and class lists in a given period, eg during Semester 1 2015. These are sometimes known as quilts.
	- Each `ClassListHistory` describes a class as it existed during a specific `TimetableSet`.
	- Each `StudentEnrolmentHistory` describes a students time in a class during a specific `TimetableSet`. They may have joined late or left early.
	- Each `TeacherEnrolmentHistory` describes a teachers time being involved in a class during a specific `TimetableSet`.  A teacher may be involved for the whole or only part of a timetable set, and there may be multiple teachers.
**/
class ClassListHistory extends Object {
	public var timetableSet:BelongsTo<TimetableSet>;
	public var schoolClass:BelongsTo<SchoolClass>;
	public var classTimes:SData<Array<{ day:Int, periodID:Int }>>;
	@:relationKey(classListID) public var teachers:HasMany<TeacherEnrolmentHistory>;
	@:relationKey(classListID) public var students:HasMany<StudentEnrolmentHistory>;
}

class TimetableSet extends Object {
	public var name:SString<25>;
	public var startDate:SDate;
	public var endDate:SDate;
	public var current:Bool;
	public var periods:ManyToMany<TimetableSet,Period>;
}

class StudentEnrolmentHistory extends Object {
	public var classList:BelongsTo<ClassListHistory>;
	public var student:BelongsTo<Student>;
	public var startDate:SDate;
	public var endDate:SDate;
}

class TeacherEnrolmentHistory extends Object {
	public var classList:BelongsTo<ClassListHistory>;
	public var teacher:BelongsTo<StaffMember>;
	public var startDate:SDate;
	public var endDate:SDate;
}

typedef HistoricClassList = {
	cls:ClassListHistory,
	teachers:List<TeacherEnrolmentHistory>,
	students:List<StudentEnrolmentHistory>,
	classTimes:List<ClassTime>
}

typedef HistoricTimetable = {
	periods:Array<Period>,
	classes:Array<HistoricClassList>
}