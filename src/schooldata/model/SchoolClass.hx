package app.coredata.model;

import sys.db.Types;
import ufront.db.Object;
import ufront.db.ManyToMany;

import app.coredata.model.*;
using Lambda;

class SchoolClass extends Object
{
	public var shortName:SString<25>;
	public var fullName:SString<255>;
	public var yeargroup:Null<STinyInt>;
	public var yeargroup2:Null<STinyInt>;
	public var frequency:STinyInt;
	public var mazeKey:String;
	
	public var subject:BelongsTo<Subject>;
	public var classTimes:HasMany<ClassTime>;
	public var students:ManyToMany<SchoolClass, Student>;
	
	@:skip public var teachers(get,never):List<StaffMember>;
	@:skip public var teacherAids(get,never):List<StaffMember>;
	@:skip public var yeargroupStr(get,never):String;

	function get_teachers() {
		var teachers = new List();
		if ( classTimes!=null ) for ( ct in classTimes ) {
			if ( !teachers.has(ct.teacher) ) teachers.add( ct.teacher );
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