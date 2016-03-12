package modelschool.core.model;

import sys.db.Types;
import ufront.db.Object;
import ufront.db.ManyToMany;
import ufront.db.DatabaseID;
import ufront.auth.model.User;
import modelschool.core.model.*;
import modelschool.core.model.ContactDetails;
using Lambda;

class Parent extends Object
{
	public var title:Null<SString<20>>;
	public var relationship:Null<SString<50>>;
	public var dbKey:SString<20>;
	public var active:SBool;

	@:validate( _.length>3 && _.indexOf("@")>1 )
	public var email:Null<SString<255>>;
	public var contactDetails:SData<ContactDetails>;

	public var person:BelongsTo<Person>;
	public var families:ManyToMany<Parent,Family>;

	@:skip public var formalName(get,null):String;
	@:skip public var fullName(get,null):String;
	@:skip public var user(get,null):User;
	@:skip public var children(get,null):List<Student>;
	@:skip public var phone(get,null):Null<String>;

	public function new() {
		super();
		this.contactDetails = [];
	}

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

	function get_children():List<Student> {
		if ( children==null ) {
			children = new List();
			for ( family in families ) {
				for ( child in family.children ) {
					if ( children.has(child)==false ) {
						children.add( child );
					}
				}
			}
		}
		return children;
	}

	function get_phone():Null<String> {
		return (this.contactDetails!=null) ? ContactDetailTools.getFirstPhoneNumber( this.contactDetails ) : null;
	}

	override public function toString() {
		return person.toString();
	}

	#if server
		public static function fromUser( u:DatabaseID<User> ) {
			var parent:Parent = null;
			if ( u!=null ) {
				var p = Person.manager.select($userID==u.toInt());
				if ( p!=null ) {
					parent = Parent.manager.select($personID==p.id);
				}
			}
			return parent;
		}
	#end
}
