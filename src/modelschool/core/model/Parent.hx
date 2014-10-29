package modelschool.core.model;

import sys.db.Types;
import ufront.db.Object;
import ufront.db.ManyToMany;
import ufront.auth.model.User;

import modelschool.core.model.*;

class Parent extends Object
{
	public var title:Null<SString<20>>;
	public var relationship:Null<SString<50>>;
	public var dbKey:SString<20>;
	public var active:SBool;
	
	@:validate( _.length>3 && _.indexOf("@")>1 )
	public var email:Null<SString<255>>;
	public var contactDetails:SData<ContactDetails> = [];

	public var person:BelongsTo<Person>;
	public var families:ManyToMany<Parent,Family>;
	
	@:skip public var formalName(get,null):String;
	@:skip public var fullName(get,null):String;
	@:skip public var user(get,null):User;

	inline function get_formalName() {
		return '$title ${person.surname}';
	}

	inline function get_user() {
		return person.user;
	}

	function get_fullName() {
		var t = (title!=null) ? '$title ' : "";
		return '$t${person.firstName} ${person.surname}';
	}

	override public function toString() {
		return person.toString();
	}

	#if server 
		public static function fromUser( u:User ) {
			var parent:Parent = null;
			if ( u!=null ) {
				var p = Person.manager.select($userID==u.id);
				if ( p!=null ) {
					parent = Parent.manager.select($personID==p.id);
				}
			}
			return parent;
		}
	#end 
}