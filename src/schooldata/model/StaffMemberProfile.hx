package app.coredata.model;

import sys.db.Types;
import ufront.db.Object;
import app.coredata.model.*;

class StaffMemberProfile extends Object
{
	public var staffMember:BelongsTo<StaffMember>;

	public var registration:SString<15>;
	public var registrationExpiry:SNull<SDate>;

	public var wwcc:SString<15>;
	public var wwccExpiry:SNull<SDate>;

	public var policeClearance:Bool;
	public var policeClearanceDate:SNull<SDate>;

	public var mobile:SString<15>;
	public var email:SString<80>;
}