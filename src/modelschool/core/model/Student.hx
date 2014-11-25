package modelschool.core.model;

import sys.db.Types;
import ufront.db.Object;
import ufront.db.ManyToMany;
import modelschool.core.model.*;
import ufront.auth.model.User;
using Lambda;

class Student extends Object
{
	public var graduatingYear:SSmallUInt;
	public var dbKey:SString<10>;
	public var active:SBool;
	
	public var person:BelongsTo<Person>;
	public var families:ManyToMany<Student,Family>;
	public var rollGroup:Null<BelongsTo<RollGroup>>;
	public var schoolHouse:Null<BelongsTo<SchoolHouse>>;
	
	public var classes:ManyToMany<Student, SchoolClass>;
	
	@:skip public var user(get,null):User;
	@:skip public var yeargroup(get,null):Int;
	@:skip public var name(get,null):String;
	@:skip public var parents(get,null):List<Parent>;

	function get_yeargroup() return getYearFromTag(graduatingYear);
	inline function get_user() return this.person.user;

	function get_name() {
		return person.toString();
	}
	
	function get_parents():List<Parent> {
		if ( parents==null ) {
			parents = new List();
			for ( family in families ) {
				for ( parent in family.parents ) {
					if ( parents.has(parent)==false ) {
						parents.add( parent );
					}
				}
			}
		}
		return parents;
	}

	override public function toString() {
		return person.toString();
	}

	public static function getYearFromTag(tag:Int) return (tag!=null) ? Date.now().getFullYear() - tag + 12 : 99; // TODO: use Serverdate as in Sheridan project.
	public static function getTagFromYear(yg:Int) return (yg!=null) ? Date.now().getFullYear() - yg + 12 : 1900; // TODO: use Serverdate as in Sheridan project.

	#if server 
		public static function fromUser( u:User ) {
			var s:Student = null;
			if ( u!=null ) {
				var p = Person.manager.select($userID==u.id);
				if ( p!=null ) {
					s = Student.manager.select($personID==p.id);
				}
			}
			return s;
		}
	#end 

}