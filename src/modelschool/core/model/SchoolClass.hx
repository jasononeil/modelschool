package modelschool.core.model;

import sys.db.Types;
import ufront.db.Object;
import ufront.db.ManyToMany;
import modelschool.core.model.*;

using Lambda;

class SchoolClass extends Object
{
	/** A shortcode for the current class. **/
	public var shortName:Null<SString<25>>;
	/** A full, human readable name for the current class. **/
	public var fullName:SString<255>;
	/** The yeargroup of the current class (or lowest yeargroup if the class spans a range of yeargroups). **/
	public var yeargroup:Null<STinyInt>;
	/** The higher yeargroup, if the class spans a range of yeargroups. Null if there is only one yeargroup. **/
	public var yeargroup2:Null<STinyInt>;
	/** The number of times this class runs each week. **/
	public var frequency:STinyInt = 0;
	/** The number of the class, if there are multiple classes in this subject. **/
	public var classNumber:STinyInt = 0;
	/** The unique database key / ID for this class in an external database. Used when running automatic imports. **/
	public var dbKey:String = "";

	/**
		If a class is "abstract", it exists as a grouping of students, but does not represent a regular class that students attend.
		Examples might include the whole school, a particular yeargroup, a sports team or a certain academic group.
		This is useful for setting attendance for that group in bulk for a particular occasion (like a camp) or directing notices to that group etc.
	**/
	public var abstractClass:Bool = false;

	/**
		The primary teacher responsible for this class.
		See also `teachers`, which shows teachers associated with various class time slots.
	**/
	public var teacher:BelongsTo<StaffMember>;

	/** The subject for this class. **/
	public var subject:Null<BelongsTo<Subject>>;
	/** The specific times this class runs during the week. **/
	public var classTimes:HasMany<ClassTime>;
	/** The students who are in this class. **/
	public var students:ManyToMany<SchoolClass, Student>;

	/**
		`teachers` is a property which retrieves not only the teacher listed in the `teacher` field, but also any listed as teachers of the various ClassTimes.
		This was if two teachers each take a couple of periods each, they can share the class.
	**/
	@:skip public var teachers(get,never):List<StaffMember>;

	@:skip public var teacherAids(get,never):List<StaffMember>;
	@:skip public var yeargroupStr(get,never):String;

	override public function toString() {
		return fullName;
	}

	function get_teachers() {
		var teachers = new List();
		if ( teacher!=null ) teachers.push( teacher );
		if ( classTimes!=null ) for ( ct in classTimes ) {
			if ( ct.teacher!=null && !teachers.has(ct.teacher) ) teachers.add( ct.teacher );
		}
		return teachers;
	}

	function get_teacherAids() {
		var teacherAids = new List();
		if ( classTimes!=null ) for ( ct in classTimes ) {
			var tAids = ct.teacherAids;
			if ( tAids!=null ) for ( ta in tAids ) {
				if ( !teachers.has(ta) ) teacherAids.add( ta );
			}
		}
		return teacherAids;
	}

	function get_yeargroupStr() {
		var y1 = switch ( yeargroup ) {
			case -1: "KG";
			case 0: "PP";
			default:
				if (yeargroup==null) "NA"
				else 'Yr $yeargroup';
		}
		return switch ( yeargroup2 ) {
			case -1: '$y1 / KG';
			case 0: '$y1 / PP';
			default:
				if ( yeargroup2==null) y1;
				else if ( yeargroup>0 ) '$y1/$yeargroup2';
				else '$y1 / Yr $yeargroup2';
		}
	}
}
