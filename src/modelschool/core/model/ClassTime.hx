package modelschool.core.model;

import ufront.db.Object;
import ufront.db.ManyToMany;
import sys.db.Types;
import modelschool.core.model.*;
using CleverSort;
using Lambda;

class ClassTime extends Object
{
	public var day:STinyUInt;
	public var occurrence:STinyInt;
	public var linkedToNextPeriod:Bool = false;

	public var teacher:BelongsTo<StaffMember>;
	public var teacherAids:ManyToMany<ClassTime,StaffMember>;
	public var room:BelongsTo<Room>;
	public var period:BelongsTo<Period>;
	public var schoolClass:BelongsTo<SchoolClass>;

	@:skip 	public var dayName(get,null):String;

	function get_dayName()
	{
		return switch day {
			case null: null;
			case 0: "Sunday";
			case 1: "Monday";
			case 2: "Tuesday";
			case 3: "Wednesday";
			case 4: "Thursday";
			case 5: "Friday";
			case 6: "Saturday";
		}
	}

	public static function sortClassTimes(cts:Iterable<ClassTime>)
	{
		var sorted = cts.array();
		sorted.cleverSort( _.day, _.period.position );
		return sorted;
	}

	public override function toString()
	{
		return '$dayName, $period, $schoolClass';
	}
}
