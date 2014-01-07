package schooldata.model;

import sys.db.Types;
import ufront.db.Object;
using ufront.util.TimeOfDayTools;
using Lambda;

import schooldata.model.*;

class Period extends Object
{
	@:validate( _.split(",").length>0 ) // Must be associated with at least 1 yeargroup
	public var yeargroupsStr:SString<31>; // Max length -1 -> 12

	@:skip public var yeargroups(get,set):Array<Int>;

	function get_yeargroups() {
		return yeargroupsStr.split(",").map( function(s) return Std.parseInt(s) );
	}

	function set_yeargroups(ygroups:Array<Int>) {
		yeargroupsStr = ygroups.join(",");
		return ygroups;
	}

	public var position:STinyInt;
	public var number:Null<STinyInt>;
	public var name:SString<15>;
	public var startTime:TimeOfDay;
	public var endTime:TimeOfDay;

	@:skip 	public var shortName(get,null):String;
	function get_shortName() {
		#if ACBC 
			// return (number != null && number > 0 && ) ? 'P$number' : name.charAt(0).toUpperCase();
			return (name.charAt(0) == "P") ? 'P$number' : name.charAt(0).toUpperCase();
		#else 
			return (number != null && number > 0) ? 'P$number' : name.charAt(0).toUpperCase();
		#end
	}
}