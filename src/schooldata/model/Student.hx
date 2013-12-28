package app.coredata.model;

import sys.db.Types;
import ufront.db.Object;
import ufront.db.ManyToMany;
import ufront.util.ServerDate;
import app.coredata.model.*;
using Lambda;

class Student extends Object
{
	public var graduatingYear:SSmallUInt;
	public var mazeKey:SString<10>;
	public var active:SBool;
	
	public var person:BelongsTo<Person>;
	public var family:BelongsTo<Family>;
	public var rollGroup:BelongsTo<RollGroup>;
	public var schoolHouse:Null<BelongsTo<SchoolHouse>>;
	
	public var classes:ManyToMany<Student, SchoolClass>;
	
	@:skip public var yeargroup(get,null):Int;
	@:skip public var isPrimarySchool(get,null):Bool;
	@:skip public var name(get,null):String;

	function get_yeargroup() return getYearFromTag(graduatingYear);

	function get_isPrimarySchool() return AppConfig.primaryYears().has( yeargroup );

	function get_name()
	{
		var first = (person.preferredName != "") ? person.preferredName : person.firstName;
		var last = person.surname;
		return '$first $last';
	}

	public static function getYearFromTag(tag:Int) return (tag!=null) ? ServerDate.now().getFullYear() - tag + 12 : 99;
	public static function getTagFromYear(yg:Int) return (yg!=null) ? ServerDate.now().getFullYear() - yg + 12 : 1900;

}