package modelschool.core.api;

import ufront.api.UFApi;
import modelschool.core.model.*;
import modelschool.core.model.ClassListHistory;
import ufront.db.DatabaseID;

class ClassListHistoryApi extends UFApi {
	public function getAllTimetableSets():List<TimetableSet> {
		return TimetableSet.manager.search(true,{ orderBy: -endDate });
	}
	
	public function getClassesForTeacher( teacherID:DatabaseID<StaffMember>, setID:DatabaseID<TimetableSet> ):HistoricTimetable {
		var set = TimetableSet.manager.get( setID.toInt() );
		var teacherEnrolments = TeacherEnrolmentHistory.manager.search( $teacherID==teacherID.toInt() );
		var classListHistoryIDs = [for (t in teacherEnrolments) t.classListID];
		var classLists = ClassListHistory.manager.search( $timetableSetID==set.id && $id in classListHistoryIDs );
		var classes = [];
		for ( cls in classLists ) {
			classes.push({
				cls: cls,
				classTimes: generateClassTimes( cls, set.periods ),
				teachers: cls.teachers,
				students: cls.students
			});
		}
		return {
			classes: classes,
			periods: Lambda.array( set.periods )
		};
	}
	
	public function getClassesForStudent( studentID:DatabaseID<Student>, setID:DatabaseID<TimetableSet> ):HistoricTimetable {
		var set = TimetableSet.manager.get( setID.toInt() );
		var studentEnrolments = StudentEnrolmentHistory.manager.search( $studentID==studentID.toInt() );
		var classListHistoryIDs = [for (t in studentEnrolments) t.classListID];
		var classLists = ClassListHistory.manager.search( $timetableSetID==set.id && $id in classListHistoryIDs );
		var classes = [];
		for ( cls in classLists ) {
			classes.push({
				cls: cls,
				classTimes: generateClassTimes( cls, set.periods ),
				teachers: cls.teachers,
				students: cls.students
			});
		}
		return {
			classes: classes,
			periods: Lambda.array( set.periods )
		};
	}
	
	function generateClassTimes( clh:ClassListHistory, periods:Iterable<Period> ):List<ClassTime> {
		var cts = new List(),
			i = 0;
		for ( data in clh.classTimes ) {
			var ct = new ClassTime();
			ct.day = data.day;
			ct.occurrence = ++i;
			ct.schoolClass = clh.schoolClass;
			ct.periodID = data.periodID;
			cts.add( ct );
		}
		return cts;
	}
	
	public function captureTimetableSet( name:String ):Void {
		closeTimetableSetsOtherThan( name );
		var timetableSet = getTimetableSet( name );
		timetableSet.periods.clear();
		var currentClasses = SchoolClass.manager.search( $frequency>0 || $abstractClass==true );
		var i = 0;
		var total = currentClasses.length;
		ufTrace( 'Capturing timetables for $total classes' );
		for ( sc in currentClasses ) {
			ufTrace( '${++i}/$total: $sc [${sc.students.length} students]' );
			if ( sc.teachers.length>0 )
				snapshotIndividualClass( sc, timetableSet );
		}
	}
	
	function closeTimetableSetsOtherThan( name:String ):Void {
		for ( ts in TimetableSet.manager.all() ) if ( ts.name!=name ) {
			ts.current = false;
			ts.save();
		}
	}

	public function getTimetableSet( name:String ):TimetableSet {
		var timetableSet = TimetableSet.manager.select( $name==name );
		if ( timetableSet==null ) {
			timetableSet = new TimetableSet();
			timetableSet.name = name;
			timetableSet.startDate = Date.now();
		}
		timetableSet.endDate = Date.now();
		timetableSet.current = true;
		timetableSet.save();
		return timetableSet;
	}

	function snapshotIndividualClass( sc:SchoolClass, timetableSet:TimetableSet ):Void {
		var classHistory = ClassListHistory.manager.select( $timetableSetID==timetableSet.id && $schoolClassID==sc.id );
		if ( classHistory==null ) {
			classHistory = new ClassListHistory();
			classHistory.schoolClass = sc;
		}
		classHistory.timetableSet = timetableSet;

		var classTimes = [];
		for ( ct in sc.classTimes ) {
			classTimes.push({day:ct.day,periodID:ct.periodID});
			timetableSet.periods.add( ct.period );
		}
		classHistory.classTimes = classTimes;
		classHistory.save();
		
		snapshotTeacherEnrolments( classHistory );
		snapshotStudentEnrolments( classHistory );
	}
	
	function snapshotTeacherEnrolments( classHistory:ClassListHistory ):Void {
		var teacherHistories = classHistory.teachers;
		for ( teacher in classHistory.schoolClass.teachers ) {
			var history = teacherHistories.filter(function(th) return th.teacherID==teacher.id).first();
			// Possible innacuracy: if a teacher leaves a class, and then joins again,
			// we will record it as one continuous enrolment, not two separate enrolments.
			if ( history==null ) {
				history = new TeacherEnrolmentHistory();
				history.classList = classHistory;
				history.teacher = teacher;
				history.startDate = Date.now();
			}
			history.endDate = Date.now();
			history.save();
		}
	}

	function snapshotStudentEnrolments( classHistory:ClassListHistory ):Void {
		var studentHistories = classHistory.students;
		for ( student in classHistory.schoolClass.students ) {
			var history = studentHistories.filter(function(sh) return sh.studentID==student.id).first();
			// Possible innacuracy: if a student leaves a class, and then joins again,
			// we will record it as one continuous enrolment, not two separate enrolments.
			if ( history==null ) {
				history = new StudentEnrolmentHistory();
				history.classList = classHistory;
				history.student = student;
				history.startDate = Date.now();
			}
			history.endDate = Date.now();
			history.save();
		}
	}
}