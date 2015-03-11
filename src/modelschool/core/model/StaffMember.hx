package modelschool.core.model;

import sys.db.Types;
import ufront.db.Object;
import ufront.db.ManyToMany;
import ufront.db.DatabaseID;
import ufront.auth.model.User;
import modelschool.core.model.*;

class StaffMember extends Object
{
	public var title:SString<20>;
	public var dbKey:SString<4>;
	public var active:SBool;
	
	public var email:Null<String>;
	public var contactDetails:SData<ContactDetails> = [];

	public var person:BelongsTo<Person>;
	@:relationKey(teacherID) public var classTimes:HasMany<ClassTime>;
	@:relationKey(teacherID) public var schoolClasses:HasMany<SchoolClass>;
	public var teacherAidClassTimes:ManyToMany<StaffMember,ClassTime>;

	public var departments:ManyToMany<StaffMember, Department>;

	@:skip public var classes(get,null):List<SchoolClass>;
	@:skip public var teachingName(get,null):String;
	@:skip public var fullName(get,null):String;
	@:skip public var name(get,null):String;
	@:skip public var user(get,null):User;

	function get_classes() {
		var classes = new List();
		if ( schoolClasses!=null ) for ( sc in schoolClasses ) {
			classes.add( sc );
		}
		if ( classTimes!=null ) for ( ct in classTimes ) {
			if ( !Lambda.has(classes,ct.schoolClass) ) classes.add( ct.schoolClass );
		}
		// Commented out for now as teacherAidClassTimes (a ManyToMany) sometimes has a null bList, and so throws an error.
		// Plus, I'm not using it yet.
		// if ( teacherAidClassTimes!=null ) 
		// 	for ( ct in teacherAidClassTimes ) 
		// 		if ( !Lambda.has(classes,ct.schoolClass) ) 
		// 			classes.add( ct.schoolClass );
			
		return classes;
	}

	function get_teachingName() {
		return '$title ${person.surname}';
	}

	function get_name() {
		return '${person.firstName} ${person.surname}';
	}

	function get_fullName() {
		if ( person.middleNames=="" || person.middleNames==null ) 
			return '$title ${person.firstName} ${person.surname}';
		else 
			return '$title ${person.firstName} ${person.middleNames} ${person.surname}';
	}

	inline function get_user() {
		return person.user;
	}

	override public function toString() {
		return person.toString();
	}

	#if server 
		public static function fromUser( u:DatabaseID<User> ) {
			var s:StaffMember = null;
			if ( u!=null ) {
				var p = Person.manager.select($userID==u.toInt());
				if ( p!=null ) {
					s = StaffMember.manager.select($personID==p.id);
				}
			}
			return s;
		}
	#end 
}