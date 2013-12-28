package app.coredata.model;

import sys.db.Types;
import ufront.db.Object;
import ufront.db.ManyToMany;
import ufront.auth.model.User;

import app.coredata.model.*;

class StaffMember extends Object
{
	public var title:SString<20>;
	public var mazeKey:SString<4>;
	public var active:SBool;

	public var person:BelongsTo<Person>;
	@:relationKey(teacherID) public var classTimes:HasMany<ClassTime>;
	public var teacherAidClassTimes:ManyToMany<StaffMember,ClassTime>;


	public var departments:ManyToMany<StaffMember, Department>;

	@:skip public var classes(get,null):List<SchoolClass>;
	@:skip public var teachingName(get,null):String;
	@:skip public var fullName(get,null):String;
	@:skip public var email(get,null):String;

	function get_classes() {
		var classes = new List();
		if ( classTimes!=null ) for ( ct in classTimes ) {
			if ( !Lambda.has(classes,ct.schoolClass) ) classes.add( ct.schoolClass );
		}
		if ( teacherAidClassTimes!=null ) for ( ct in teacherAidClassTimes ) {
			if ( !Lambda.has(classes,ct.schoolClass) ) classes.add( ct.schoolClass );
		}
		return classes;
	}

	function get_teachingName() {
		var initial = person.firstName.charAt( 0 );
		return '$title $initial. ${person.surname}';
	}

	function get_fullName() {
		if ( person.middleNames=="" || person.middleNames==null ) 
			return '$title ${person.firstName} ${person.surname}';
		else 
			return '$title ${person.firstName} ${person.middleNames} ${person.surname}';
	}

	function get_email() {
		var username = person.user.username;
		var domain = "sheridancollege.com.au";
		return '$username@$domain';
	}

	#if server 
		public static function fromUser( u:User ) {
			var s:StaffMember = null;
			if ( u!=null ) {
				var p = Person.manager.select($userID==u.id);
				if ( p!=null ) {
					s = StaffMember.manager.select($personID==p.id);
				}
			}
			return s;
		}
	#end 
}