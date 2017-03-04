package modelschool.core.imports;
import modelschool.core.model.*;
import ufront.auth.model.*;
import modelschool.core.model.Gender;
import haxe.Utf8;
import sys.FileSystem;
import sys.db.Connection;
using tink.CoreApi;
using StringTools;
using Lambda;

class MazeImport
{
	var mazeCnx:Connection;
	var modelSchoolCnx:Connection;
	var importConfig:{
		features: {
			primaryTimetables:Bool
		},
		schoolInfo: {
			shortName:String,
			domain:String
		},
		schoolSetup: {
			yeargroups: {
				primary:Array<Int>,
				secondary:Array<Int>
			},
			homeroom: {
				periodNumbers:Array<Int>
			}
		},
		usernameCorrections:Map<String,String>
	};

	public function new(importConfig, mazeCnx, modelSchoolCnx) {
		this.importConfig = importConfig;
		this.mazeCnx = mazeCnx;
		this.modelSchoolCnx = modelSchoolCnx;
	}

	public function doImportstudents()
	{
		var cnx = connectToMazeTransferDB();

		trace ("Getting list of all current students...");
		var sql = "SELECT ST.*,
				KGN.DESCRIPTION AS NATION_STR,
				KIS.DESCRIPTION AS ABORIGINAL_STR,
				KGL.DESCRIPTION AS LANG_STR,
				KGS.SCHOOL_NAME AS PREVIOUS_STR,
				KGS.LOCAL_AREA AS PREVIOUS_AREA_STR,
				KGT.DESCRIPTION AS BIRTH_COUNTRY_STR
			FROM `ST`
				LEFT OUTER JOIN KGN ON KGN.NATION = ST.NATION
				LEFT OUTER JOIN KIS ON KIS.KISKEY = ST.ABORIGINAL
				LEFT OUTER JOIN KGL ON KGL.KGLKEY = ST.LANG
				LEFT OUTER JOIN KGS ON KGS.SCHOOL = ST.PREVIOUS
				LEFT OUTER JOIN KGT ON KGT.KGTKEY = ST.BIRTH_COUNTRY
			WHERE `STATUS` = 'FULL'";

		var rs = cnx.request(sql).results();
		var count = Lambda.count(rs);
		trace ('  Found $count students');

		var cnx = connectToModelSchoolDB();

		var allCurrentStudents = Student.manager.all();
		var allCurrentPeople = Person.manager.all();
		var allCurrentUsers = User.manager.all();
		var allCurrentStudentPhotos = StudentPhoto.manager.all();
		var allCurrentProfiles = StudentProfile.manager.all();
		var allCurrentRollGroups = RollGroup.manager.all();
		var allCurrentSchoolHouses = SchoolHouse.manager.all();
		var allCurrentFamilies = Family.manager.all();

		var studentGroup = Group.manager.select($name == "students");
		var usersGroup = Group.manager.select($name == "users");

		var dbKeysNotFound = allCurrentStudents.map( function(s) return s.dbKey );

		var i = 0;
		for (row in rs)
		{
			i++;
			var s:Student;
			var p:Person;
			var u:User;
			var sPhoto:StudentPhoto;
			var sProfile:StudentProfile;

			// Check if the rows already exist
			var dbKey:String = cast row.STKEY;

			dbKeysNotFound.remove( dbKey );

			var action = "";
			s = allCurrentStudents.filter(function (s) { return s.dbKey == dbKey; }).first();
			if (s != null)
			{
				p = allCurrentPeople.filter(function (p) { return p.id == s.personID; }).first();
				u = allCurrentUsers.filter(function (u) { return u.id == p.userID; }).first();
				sPhoto = allCurrentStudentPhotos.filter(function (sp) {return sp.studentID == s.id; }).first();
				sProfile = allCurrentProfiles.filter(function (sp) return sp.studentID == s.id).first();
				action = "Updated";
			}
			else action = "Created";

			// don't use the constructor for User because we don't want to generate the password hash now
			if (u == null) u = Type.createEmptyInstance(User);
			if (s == null) s = new Student();
			if (p == null) p = new Person();
			if (sProfile == null) sProfile = new StudentProfile();
			if (sPhoto == null) sPhoto = new StudentPhoto();

			// Tag / graduating year
			var tagString = sanitiseString( row.TAG );
			tagString = ~/[^0-9]/g.replace( tagString, "" );
			var graduatingYear:Int = Std.parseInt( tagString );

			// User;
			var first = sanitiseString(row.FIRST_NAME).toLowerCase();
			var surname = sanitiseString(row.SURNAME).toLowerCase();
			var username = '$first$surname$graduatingYear';
			username = username.replace(' ', '');
			username = username.replace('\'', '');
			username = username.replace('-', '');
			if (u.username != username || u.password == null || u.salt == null)
			{
				u.username = username;
				if (u.password == null)
				{
					u.forcePasswordChange = true;
					u.password = "";
				}
				if (u.salt == null) u.salt = "";
				u.save();
			}
			u.groups.add(studentGroup);
			u.groups.add(usersGroup);

			// Person;
			p.firstName = sanitiseString(row.FIRST_NAME);
			p.surname = sanitiseString(row.SURNAME);
			p.middleNames = sanitiseString(row.SECOND_NAME);
			p.preferredName = (row.PREF_NAME == row.FIRST_NAME) ? "" : sanitiseString(row.PREF_NAME);
			p.gender = (row.GENDER == "M") ? Gender.Male : Gender.Female;
			p.birthday = row.BIRTHDATE;
			p.user = u;
			p.save();

			// Student;
			var rollGroup = allCurrentRollGroups.filter(function (rg) return rg.name == row.ROLL_GROUP).first();
			var family = allCurrentFamilies.filter(function (fam) return fam.dbKey == row.FAMILY).first();
			var schoolHouse = allCurrentSchoolHouses.filter(function (sh) return sh.shortName == row.HOUSE).first();
			if (s.graduatingYear != graduatingYear
				|| s.dbKey != row.STKEY
				|| s.personID != p.id
				|| s.rollGroupID != rollGroup.id
				|| s.schoolHouseID != schoolHouse.id
				|| s.active != true) {
				s.graduatingYear = graduatingYear;
				s.dbKey = row.STKEY;
				s.active = true;
				s.person = p;

				if (rollGroup != null)
				{
					s.rollGroupID = rollGroup.id;
				}
				else trace ("Roll group not found: " + row.ROLL_GROUP);

				if (schoolHouse != null)
				{
					s.schoolHouseID = schoolHouse.id;
				}
				else trace ("School house not found: " + row.HOUSE);

				if (family != null) {
					s.families.setList([family]);
				}
				else trace ("Family not found: " + row.FAMILY);

				s.save();
			}

			// StudentPhoto;
			if (sPhoto.photo != row.STUDENT_PIC)
			{
				sPhoto.photo = row.STUDENT_PIC;
				sPhoto.student = s;
				sPhoto.save();
			}

			// StudentProfile;
			sProfile.placeOfBirth = sanitiseString(row.BIRTHPLACE);
			sProfile.countryOfBirth = sanitiseString(row.BIRTH_COUNTRY_STR); // Foreign Key KGT.KGTKEY , KGT.DESCRIPTION
			sProfile.residentStatus = switch (sanitiseString(row.RES_STATUS)) {
				case "C": "Citizen";
				case "R": "Resident";
				case "O": "Overseas";
				default: "";
			};
			sProfile.nationality = (row.NATION_STR != null) ? sanitiseString(row.NATION_STR) : sanitiseString(row.NATION);
			sProfile.indigenousStatus = sanitiseString(row.ABORIGINAL_STR); // Foreign key - KIS.KISKEY, KIS.DESCRIPTION
			sProfile.languageAtHome = sanitiseString(row.LANG_STR); // Foreign key KGL.KGLKEY - KGL.DESCRIPTION
			sProfile.dateOfEntry = row.ENTRY;
			sProfile.yeargroupOfEntry = sanitiseString(row.ENTRY_GRADE);
			sProfile.idCardExpiry = row.EXPIRY_DATE; // Need to verify if this is correct
			sProfile.boarder = (row.BOARDER != null && row.BOARDER == "Y");
			sProfile.examNumber = (row.EXAM != null) ? row.EXAM : null;
			sProfile.previousSchool = "";
			if (row.PREVIOUS_STR != null)
			{
				sProfile.previousSchool = sanitiseString(row.PREVIOUS_STR);
				if (row.PREVIOUS_AREA_STR != null)
				{
					sProfile.previousSchool += ' (${row.PREVIOUS_AREA_STR})';
				}
			}
			else if (row.PREVIOUS != null)
			{
				sProfile.previousSchool = sanitiseString(row.PREVIOUS);
			}
			sProfile.doctor = sanitiseString(row.DOCTOR);
			sProfile.emergencyContacts = extractContactsFromStrings([row.EMERGENCY, row.EMERG_CONTACT01, row.EMERG_CONTACT02]);
			sProfile.medicalAlert = (row.MEDICAL_ALERT != null && row.MEDICAL_ALERT == "Y");
			sProfile.medicalCondition1 = sanitiseString(row.MED_CONDA);
			sProfile.medicalCondition2 = sanitiseString(row.MED_CONDB);
			sProfile.disability = (row.DISABILITY != null && row.DISABILITY == "Y");
			sProfile.medicalNotes = sanitiseString(row.MEDICAL);
			sProfile.accessAlert = (row.ACCESS_ALERT != null && row.ACCESS_ALERT == "Y");
			sProfile.accessType = sanitiseString(row.ACCESS_TYPE);
			sProfile.accessNotes = sanitiseString(row.ACCESS);
			sProfile.studentID = s.id;
			sProfile.save();

			trace ('$action ${p.firstName} ${p.surname} ${u.username} ${s.dbKey} ($i/$count)');
		}

		for ( dbKey in dbKeysNotFound ) {
			var s = allCurrentStudents.filter(function (s) { return s.dbKey == dbKey; }).first();
			s.classes.clear();
			s.active = false;
			s.save();
		}
	}

	function extractContactsFromStrings(inArray:Array<String>)
	{
		var outArray = [];
		if (inArray != null)
		{
			for (str in inArray)
			{
				if (str != null)
				{
					var contact = {
						name: "",
						phone: ""
					}
					var matchPhoneNum = ~/([0-9][0-9 ]{6,}[0-9])/;
					if (matchPhoneNum.match(str))
					{
						contact.phone = matchPhoneNum.matched(1);
						contact.name = str.replace(contact.phone, "");
					}
					else
					{
						contact.name = str;
					}
					outArray.push(contact);
				}
			}
		}
		return outArray;
	}

	public function doImportstaff()
	{
		var cnx = connectToMazeTransferDB();

		trace ("Getting list of all current staff...");
		var sql = "SELECT * FROM `SF`";
		var rs = cnx.request(sql).results();
		var count = Lambda.count(rs);
		trace ('  Found $count staff');

		connectToModelSchoolDB();

		var allCurrentStaff = StaffMember.manager.all();
		var allCurrentPeople = Person.manager.all();
		var allCurrentUsers = User.manager.all();
		var allCurrentProfiles = StaffMemberProfile.manager.all();

		var staffGroup = Group.manager.select($name == "staff");
		var teachersGroup = Group.manager.select($name == "teachers");
		var usersGroup = Group.manager.select($name == "users");
		var nonTeachingStaffGroup = Group.manager.select($name == "nonTeachingStaff");

		var testPassword = User.generatePasswordHash("test", "test");
		var domain = importConfig.schoolInfo.domain;


		var i = 0;
		for (row in rs)
		{
			i++;
			var s:StaffMember;
			var p:Person;
			var u:User;
			var sProfile:StaffMemberProfile;

			// Check if the rows already exist
			var dbKey:String = cast row.SFKEY;

			var action:String;
			s = allCurrentStaff.filter(function (s) { return s.dbKey == dbKey; }).first();
			if (s != null)
			{
				p = allCurrentPeople.filter(function (p) { return p.id == s.personID; }).first();
				u = allCurrentUsers.filter(function (u) { return u.id == p.userID; }).first();
				sProfile = allCurrentProfiles.filter(function (pr) { return pr.staffMemberID == s.id; } ).first();
				action = "Updated";
			}
			else action = "Created";

			// don't use the constructor for User because we don't want to generate the password hash now
			if (u == null) u = Type.createEmptyInstance(User);
			if (p == null) p = new Person();
			if (s == null) s = new StaffMember();
			if (sProfile == null) sProfile = new StaffMemberProfile();



			// User;
			var email:String = sanitiseString(row.SF_EMAIL);
			if (email == null) email = 'unknownuser_$dbKey@$domain';
			var username:String;
			if ( importConfig.usernameCorrections.exists(dbKey) ) {
				username = importConfig.usernameCorrections[dbKey];
			}
			else if ( email.indexOf(domain)>-1 )
			{
				username = email.replace('@$domain', '');
			}
			else
			{
				var last = sanitiseString(row.SURNAME).toLowerCase();
				var firstInitial = sanitiseString(row.FIRST_NAME).charAt(0).toLowerCase();
				username = firstInitial + last;
			}
			username = username.replace(' ', '');
			username = username.replace('\'', '');
			username = username.replace('-', '');
			if (u.username != username || u.password == null || u.salt == null)
			{
				u.username = username;
				if (u.password == null)
				{
					u.forcePasswordChange = true;
					u.password = testPassword;
				}
				if (u.salt == null) u.salt = "test";
				u.save();
			}
			u.groups.add(usersGroup);
			u.groups.add(staffGroup);
			if (row.STAFF_TYPE == 'T') u.groups.add(teachersGroup);
			if (row.STAFF_TYPE == 'N') u.groups.add(nonTeachingStaffGroup);

			// Person;
			p.firstName = sanitiseString(row.FIRST_NAME);
			p.surname = sanitiseString(row.SURNAME);
			p.middleNames = sanitiseString(row.SECOND_NAME);
			p.preferredName = (row.PREF_NAME == row.FIRST_NAME) ? "" : sanitiseString(row.PREF_NAME);
			p.gender = (row.GENDER == "M") ? Gender.Male : Gender.Female;
			p.birthday = row.BIRTHDATE;
			p.user = u;
			p.save();

			// Set up the departments...
			row.FACULTY01; // String representing department, possibly...

			var active:Bool = row.STATUS!=null && row.STATUS!="L";

			// StaffMember:
			if (p != s.person
				|| row.TITLE != s.title
				|| s.dbKey != dbKey
				|| s.active != active )
			{
				s.active = active;
				s.person = p;
				s.title = sanitiseString(row.TITLE);
				s.dbKey = dbKey;
				s.phone = sanitiseString(row.MOBILE);
				s.email = sanitiseString(row.SF_EMAIL);
				s.save();
			}

			// StaffProfile
			sProfile.registration = sanitiseString(row.REGISTRATION);
			sProfile.registrationExpiry = row.REGO_EXPIRY; // date
			sProfile.wwcc = sanitiseString(row.WWW_CHECK);
			sProfile.wwccExpiry = row.WWW_EXPIRY_DATE; // Date
			sProfile.policeClearance = (row.POLICE_CLEARANCE == "Y");
			sProfile.policeClearanceDate = row.CLEARANCE_DATE; // date
			sProfile.staffMember = s;
			sProfile.save();

			trace ('$action ${p.firstName} ${p.surname} ${u.username} ${s.dbKey} ($i/$count)');
		}

		// Create a staff member called "No Teacher"
		var noTeacherStaffMember:StaffMember = allCurrentStaff.filter(function (s) { return s.dbKey == "nt"; }).first();
		if (noTeacherStaffMember == null)
		{
			noTeacherStaffMember = new StaffMember();
			var noTeacherP = new Person();
			var noTeacherU = new User("noteacher", null);
			var noTeacherProfile = new StaffMemberProfile();

			noTeacherU.save();

			noTeacherP.user = noTeacherU;
			noTeacherP.firstName = "No Teacher";
			noTeacherP.surname = "";
			noTeacherP.preferredName = "";
			noTeacherP.middleNames = "";
			noTeacherP.birthday = Date.now();
			noTeacherP.gender = Male;
			noTeacherP.save();

			noTeacherStaffMember.person = noTeacherP;
			noTeacherStaffMember.dbKey = "nt";
			noTeacherStaffMember.title = "Mr.";
			noTeacherStaffMember.active = false;
			noTeacherStaffMember.save();

			noTeacherProfile.staffMember = noTeacherStaffMember;
			trace ('Created no-teacher staff memeber');
		}
		else if ( noTeacherStaffMember.active )
		{
			noTeacherStaffMember.active = false;
			noTeacherStaffMember.save();
		}
	}

	public function doImportparents()
	{
		var cnx = connectToMazeTransferDB();
		trace ("Getting list of all families...");
		var sql = "SELECT * FROM `DF`";
		var familyRows:List<Dynamic> = cnx.request(sql).results();
		var familyCount = familyRows.count();
		trace ('  Found $familyCount families');

		trace ("Getting list of all homes...");
		var sql = "SELECT * FROM `UM`";
		var homeRows:List<Dynamic> = cnx.request(sql).results();
		var homeCount = homeRows.count();
		trace ('  Found $homeCount homes');

		connectToModelSchoolDB();

		var allCurrentFamilies = Family.manager.all();
		var allCurrentParents = Parent.manager.all();
		var allCurrentHomes = Home.manager.all();

		var i = 0;
		for (r in homeRows)
		{
			var row:Dynamic = r;
			i++;
			var action:String;
			var h:Home = allCurrentHomes.filter(function (home) return home.dbKey == row.UMKEY).first();
			if (h == null)
			{
				action = "Created";
				h = new Home();
				allCurrentHomes.push( h );
			}
			else action = "Updated";

			h.dbKey = row.UMKEY;
			h.state = sanitiseString( row.STATE );
			h.postcode = sanitiseString( row.POSTCODE );
			h.phone = sanitiseString( row.TELEPHONE );
			h.fax = sanitiseString( row.FAX );

			var address01 = sanitiseString( row.ADDRESS01 );
			var address02 = sanitiseString( row.ADDRESS02 );
			var address03 = sanitiseString( row.ADDRESS03 );

			h.address = "";
			if ( address01!="" ) h.address += address01;
			if ( address02!="" ) h.address += "\n"+address02;
			if ( address03!="" ) h.address += "\n"+address03;

			h.save();
			trace ('$action Home ${h.dbKey} ($i/$homeCount)');
		}

		var i = 0;
		for (r in familyRows)
		{
			var row:Dynamic = r;
			i++;
			var action:String;
			var family:Family = allCurrentFamilies.filter(function (fam) return fam.dbKey == row.DFKEY).first();
			if (family == null)
			{
				action = "Created";
				family = new Family();
				family.save();
				allCurrentFamilies.push(family);
			}
			else action = "Updated";

			// TODO: consider if the family should have a general surname.
			// (In addition to each individual having one).
			// sanitiseString(row.SURNAME);

			family.dbKey = row.DFKEY;
			var motherEmail = sanitiseString(row.M_EMAIL);
			var mother = getOrCreateParent(allCurrentParents, family.dbKey + '_M', motherEmail);
			mother.person.firstName = sanitiseString(row.MNAME);
			mother.person.surname = sanitiseString(row.MSURNAME);
			mother.email = motherEmail;
			mother.phone = sanitiseString(row.MMOBILE);
			mother.person.save();
			mother.save();
			family.parents.add(mother);
			var fatherEmail = sanitiseString(row.F_EMAIL);
			var father = getOrCreateParent(allCurrentParents, family.dbKey + '_F', fatherEmail);
			father.person.firstName = sanitiseString(row.FNAME);
			father.person.surname = sanitiseString(row.FSURNAME);
			father.email = sanitiseString(row.F_EMAIL);
			father.phone = sanitiseString(row.FMOBILE);
			father.person.save();
			father.save();
			family.parents.add(father);

			// TODO: support work phone numbers.
			// sanitiseString(row.MBUS_PHONE);
			// sanitiseString(row.FBUS_PHONE);

			family.homeTitle = sanitiseString(row.HOMETITLE);
			family.mailTitle = sanitiseString(row.MAILTITLE);
			family.billingTitle = sanitiseString(row.BILLINGTITLE);

			function getHome( dbKey:String ) {
				return allCurrentHomes.filter( function (h) return h.dbKey==dbKey ).first();
			}

			family.homeAddress = getHome( row.HOMEKEY );
			family.mailAddress = getHome( row.MAILKEY );
			family.billingAddress = getHome( row.BILLINGKEY );

			family.save();
			trace ('$action Family ${family.dbKey} ${mother} ${father} ($i/$familyCount)');
		}
	}

	function getOrCreateParent(allCurrentParents, dbKey, username) {
		var parent = allCurrentParents.filter(function (p) return p.dbKey == dbKey).first();
		if (parent == null) {
			var user = new User(username);
			user.save();

			var person = new Person();
			person.user = user;
			person.save();

			parent = new Parent();
			parent.dbKey = dbKey;
			parent.person = person;
			parent.save();
		}
		return parent;
	}

	public function doImportrollgroups()
	{
		var cnx = connectToMazeTransferDB();
		trace ("Getting list of all roll groups...");
		var sql = "SELECT * FROM `KGC`";
		var rs = cnx.request(sql).results();
		var count = rs.count();
		trace ('  Found $count roll groups');

		var cnx = connectToModelSchoolDB();

		var allCurrentRollGroups = RollGroup.manager.all();
		var allCurrentTeachers = StaffMember.manager.all();

		for (row in rs)
		{
			var r:RollGroup;

			// Check if the rows already exist, create it if not
			var name:String = row.ROLL_GROUP;
			r = allCurrentRollGroups.filter(function (r) { return r.name == name; }).first();
			var action = (r == null) ? "Created" : "Updated";

			// name and description
			if (r == null) r = new RollGroup();
			r.name = name;
			r.description = sanitiseString(row.DESCRIPTION);

			// teacher
			var teacherdbKey = sanitiseString(row.TEACHER);
			var teacher = allCurrentTeachers.filter(function (t) return t.dbKey == teacherdbKey).first();
			if (teacher == null) trace ('Teacher $teacherdbKey not found for roll group $name');
			else r.teacher = teacher;

			// yeagroup
			// TODO: add some of this to the incoming config...
			var numberAtStart = ~/([0-9\/]+)/;
			if ( name.startsWith("KG.") || name.startsWith("00K") || name.startsWith("0.") )
			{
				r.yeargroup = -1; // Kindy
				r.yeargroup2 = null;
			}
			else if ( name=="PP" || name.startsWith("00P") || name.startsWith("00.") || has(name,"PREP") )
			{
				r.yeargroup = 0; // Pre Primary
				r.yeargroup2 = null;
			}
			else if ( name=="P/Y1" )
			{
				r.yeargroup = 0; // Pre Primary
				r.yeargroup2 = 1; // Grade 1
			}
			else if ( name.indexOf("LEFT")>-1 )
			{
				r.yeargroup = 13;
				r.yeargroup2 = 1;
			}
			else if ( numberAtStart.match(name) )
			{
				var yString = numberAtStart.matched(1);
				// At Geelong, we have joint classes, such as Y012 - year 1 and 2 combined
				// (as opposed to Y12, which is year 12.  Sigh....)
				// Check for this pattern, and default to the first yeargroup
				if (yString.startsWith('0') && Std.parseInt(yString) >= 12)
				{
					r.yeargroup = Std.parseInt(yString.charAt(1));
					r.yeargroup2 = Std.parseInt(yString.charAt(2));
				}
				// At ABC join yeargroup classes have a "/" in their name eg "Y3/4"
				else if (yString.indexOf('/') > -1)
				{
					var parts = yString.split('/');
					r.yeargroup = (parts[0]=="P") ? 0 : Std.parseInt(parts[0]);
					r.yeargroup2 = (parts[1]=="P") ? 0 : Std.parseInt(parts[1]);
				}
				else
				{
					r.yeargroup = Std.parseInt(yString);
					r.yeargroup2 = null;
				}
			}
			else
			{
				throw 'Unknown rollgroup name: $name';
			}

			r.save();
			var teacherName = (teacher != null) ? teacher.fullName : "NULL-TEACHER";
			trace ('$action ${r.name} ${r.description} (Yr ${r.yeargroupStr}) with teacher $teacherName');
		}
	}

	public function doCleanuprollgroups()
	{
		var allSchoolClasses = SchoolClass.manager.all();

		for (sc in allSchoolClasses)
		{
			var needsDeleting = false;

			// TODO: use import config instead here.s
			#if QBC
				var rogueSecondaryFormClass = sc.fullName.startsWith("FORM ");
				var duplicatePrimaryFormClass = sc.dbKey.startsWith("_rg") && !sc.dbKey.startsWith("_rgY") && sc.yeargroup<7;
				needsDeleting = rogueSecondaryFormClass || duplicatePrimaryFormClass;
			#elseif ACBC
				var mazeFormClass = sc.fullName.indexOf('Form')>-1 && sc.dbKey.startsWith("_rg")==false;
				// If each class time falls outside of the periods labelled "FORM", then it's not a form period.  Maybe it's an assembly etc
				var notInFormPeriod = sc.classTimes.foreach( function (ct) return ct.period.name.indexOf("FORM")>-1 );
				needsDeleting = (mazeFormClass&&notInFormPeriod);
			#end

			if ( needsDeleting ) {
				trace ('Deleting $sc (${sc.dbKey} ${sc.fullName}) with ClassTimes ${sc.classTimes}');
				for (ct in sc.classTimes) {
					ct.delete();
				}
				sc.students.clear();
				sc.delete();
			}
		}
	}

	inline function has(haystack:String, needle:String)
	{
		return haystack.indexOf(needle) > -1;
	}

	public function doImportschoolhouses()
	{
		var cnx = connectToMazeTransferDB();
		trace ("Getting list of all School Houses...");
		var sql = "SELECT * FROM `KGH`";
		var rs = cnx.request(sql).results();
		var count = rs.count();
		trace ('  Found $count School Houses');

		connectToModelSchoolDB();

		var allCurrentHouses = SchoolHouse.manager.all();

		for (row in rs)
		{
			var h:SchoolHouse;
			var shortName = sanitiseString(row.HOUSE);
			var name = sanitiseString(row.DESCRIPTION);

			// Check if the rows already exist, create it if not
			h = allCurrentHouses.filter(function (h) return h.shortName == shortName).first();
			var action = (h == null) ? "Created" : "Updated";
			if (h == null) h = new SchoolHouse();

			// Save the names
			h.shortName = shortName;
			h.name = name;

			h.save();
			trace ('$action ${h.shortName}: ${h.name}');
		}
	}

	public function doSubjects()
	{
		var cnx = connectToMazeTransferDB();

		trace ("Getting list of all current staff...");
		var sql = "SELECT * FROM `SU`";
		var rs = cnx.request(sql).results();
		var count = rs.count();
		trace ('  Found $count subjects');

		connectToModelSchoolDB();

		var allCurrentSubjects = Subject.manager.all();
		var allCurrentStaff = StaffMember.manager.all();

		var i = 0;
		for (row in rs)
		{
			i++;
			var s:Subject;

			// Check if the rows already exist, create it if not
			var dbKey:String = row.SUKEY;
			s = allCurrentSubjects.filter(function (s) { return s.dbKey == dbKey; }).first();
			var action = (s == null) ? "Created" : "Updated";

			if (s == null) s = new Subject();
			s.name = sanitiseString(row.FULLNAME);
			s.dbKey = dbKey;

			if (row.SUBJECT_ACADEMIC_YEAR != null)
			{
				var year:String = row.SUBJECT_ACADEMIC_YEAR;
				s.yeargroup = Std.parseInt(year.substr(1));
			}
			if (s.yeargroup == null)
			{
				var shortname = sanitiseString(row.SHORTNAME);
				s.yeargroup = Std.parseInt(shortname.substr(0,2));
			}
			if (s.yeargroup == null)
			{
				// This subject is not easily guessable
				// Leave it null, and we can check class per class, but even then
				// we are not guarenteed - some classes have 11s and 12s.
				s.yeargroup = null;
			}

			if (row.CONTACT_TEACHER != null)
			{
				var teacherMazeID:String = row.CONTACT_TEACHER;
				if (teacherMazeID != null && teacherMazeID != "")
				{
					var teacher = allCurrentStaff.filter(function (staff) { return staff.dbKey == teacherMazeID; }).first();
					if (teacher != null) s.contactTeacher = teacher;
				}
			}

			// row.CURR_OFFERED; // Not sure if this is relevant
			// row.SEMESTER; // Seems to be 0,1,2,3 ... not sure what they mean

			s.save();
			trace ('$action ${s.name} ${s.yeargroup} ${s.dbKey} ($i/$count)');
		}
	}

	public function doCreatepsperiodsmanually(from:Int, to:Int)
	{
		var yeargroups = [ for (y in from...(to + 1)) y ];
		var periods:Array<Pair<String,Null<Int>>> = [
			new Pair("Period 1", 1),
			new Pair("Recess", null),
			new Pair("Period 2", 2),
			new Pair("Lunch", null),
			new Pair("Period 3", 3)
		];
		createPeriods(periods, yeargroups);
	}

	@help("Create periods F,1,2,R,3,4,L,5,6,7 for the yeargroups specified")
	public function doCreatehsperiodsmanually(fromYear:String, toYear:String)
	{
		var from = Std.parseInt(fromYear);
		var to = Std.parseInt(toYear);
		var yeargroups = [ for (y in from...(to + 1)) y ];
		var periods:Array<Pair<String,Null<Int>>> = [
			new Pair("Form", 0),
			new Pair("Period 1", 1),
			new Pair("Period 2", 2),
			new Pair("Recess", null),
			new Pair("Period 3", 3),
			new Pair("Period 4", 4),
			new Pair("Lunch", null),
			new Pair("Period 5", 5),
			new Pair("Period 6", 6),
			new Pair("Period 7", 7)
		];
		createPeriods(periods, yeargroups);
	}

	function createPeriods( periods:Array<Pair<String,Null<Int>>>, yeargroups:Array<Int> )
	{
		var pos = 0;
		for (pair in periods) {

			var periodName = pair.a;

			var p = new Period();
			p.startTime = 0;
			p.endTime = 0;

			p.position = ++pos;
			p.name = periodName;
			p.number = pair.b;
			p.yeargroups = yeargroups;

			p.save();
			trace ('  Saving Period[${p.id}] : ${p.name} for yeargroups ${p.yeargroups}');
		}
	}

	public function doDeleteperiods(fromYear:String, toYear:String)
	{
		throw "Not implemented";
	}

	public function doImportmazeperiods(fromYear:String, toYear:String)
	{
		var from = Std.parseInt(fromYear);
		var to = Std.parseInt(toYear);
		var yeargroups = [ for (y in from...(to + 1)) y ];

		var cnx = connectToMazeTransferDB();
		var sql = "SELECT * FROM `TH`
					ORDER BY THKEY DESC
					LIMIT 1";
		var rs = cnx.request(sql).results();
		var row = rs.first();

		var cnx = connectToModelSchoolDB();

		var newPeriods = new List();

		var numPeriods = row.THROWS;
		for (i in 1...numPeriods+1)
		{
			var zPadPeriodNumber = Std.string(i).lpad('0', 2);
			var columnName = "TH_RLABEL" + zPadPeriodNumber;
			var periodName = Reflect.field(row, columnName);

			var num:Null<Int> = null;
			var extractNumbers = ~/(\d+)/;
			extractNumbers.match(periodName);
			if (extractNumbers.match(periodName) && periodName.indexOf("Lunch") == -1) {
				num = Std.parseInt( extractNumbers.matched(0) );
			}
			else if (periodName.indexOf("Form") > -1) {
				num = 0;
			}

			var p = new Period();
			p.startTime = 0;
			p.endTime = 0;
			p.position = i;
			p.yeargroups = yeargroups;
			p.name = periodName;
			p.number = num;

			p.save();
			trace ('  Saving Period[${p.id}] : ${p.name} #${p.position} for yeargroups ${p.yeargroups}');
		}

		// TODO: use local config instead
		#if ABC
			// Create the form period
			var p = new Period();
			p.startTime = 0;
			p.endTime = 0;
			p.position = 0;
			p.yeargroups = yeargroups;
			p.name = "Form";
			p.number = 0;
			p.save();
			newPeriods.add(p);
		#end
	}

	public function doSetuprollgroupsasclasses()
	{
		// Collect data we'll be referring to
		var allCurrentStudents = Student.manager.all();
		var allCurrentSubjects = Subject.manager.all();
		var allCurrentStaff = StaffMember.manager.all();
		var allPeriods = Period.manager.search(true, { orderBy: position });
		var allCurrentRollGroups = RollGroup.manager.all();
		var allCurrentRooms = Room.manager.all();
		var allCurrentSchoolClasses = SchoolClass.manager.all();
		var allCurrentClassTimes = ClassTime.manager.all();

		var rollGroups = allCurrentRollGroups.filter(function (rg) {
			var hasStudents = (allCurrentStudents.filter(function (st) return (st.rollGroupID == rg.id)).length > 0);
			return hasStudents;
		});
		trace ('Found ${rollGroups.length} roll groups to set up...');

		var defaultRoom = Room.manager.search( $name=="" ).first();
		if ( defaultRoom==null ) {
			defaultRoom = new Room();
			defaultRoom.name = "";
			defaultRoom.description = "Room Not Set";
			defaultRoom.save();
		}

		for (rg in rollGroups)
		{
			var isPrimarySchool = this.importConfig.schoolSetup.yeargroups.primary.has(rg.yeargroup);
			var dbKey = "_rg" + rg.name;
			rg.yeargroup = (rg.yeargroup == null) ? 1 : rg.yeargroup;
			trace ('Working on Rollgroup: $dbKey (Yr ${rg.yeargroup})');

			// Get or create suShortbject
			var su = allCurrentSubjects.filter(function (su) return su.dbKey == dbKey).first();
			if (su == null) su = new Subject();
			su.dbKey = dbKey;
			su.contactTeacherID = rg.teacherID;
			su.name = rg.description;
			su.yeargroup = rg.yeargroup;
			su.save();

			// Get or create room
			var room:Room;
			if ( isPrimarySchool ) {
				room = allCurrentRooms.filter(function (r) return r.name == rg.name).first();
				if (room == null) room = new Room();
				room.name = rg.name;
				room.description = "Primary " + rg.name;
				room.save();
			}
			else {
				// TODO: use a real room, not a default room
				room = defaultRoom;
			}

			var numStudents = allCurrentStudents.filter(function (student) return student.rollGroupID == rg.id).length;
			if (numStudents == 0) {
				trace ("No students in this roll group... skipping it.");
				continue;
			}
			else {
				// Get class periods for current yeargroup
				#if GBC
					var periods = allPeriods.filter( function (p) return (p.yeargroups!=null && p.yeargroups.has(rg.yeargroup) && (p.number!=null || p.name=="Homeroom")) );
				#else
					var periods = allPeriods.filter( function (p) return (p.yeargroups!=null && p.yeargroups.has(rg.yeargroup) && p.number != null) );
				#end

				// Get or create school class
				var sc = allCurrentSchoolClasses.filter(function (sc) return sc.dbKey == dbKey).first();
				if (sc == null) sc = new SchoolClass();
				sc.shortName = rg.name;
				sc.fullName = rg.description;
				sc.yeargroup = rg.yeargroup;
				sc.yeargroup2 = rg.yeargroup2;
				sc.frequency = isPrimarySchool ? periods.length*5 : 5;
				sc.dbKey = dbKey;
				sc.subjectID = su.id;
				sc.save();
				trace (' School Class created with ID ${sc.id}');

				// Set up the class times
				if ( isPrimarySchool && importConfig.features.primaryTimetables==false ) {
					// Add class times for every period of the day
					var occurrence = 1;
					for (day in 0...7)
					{
						if (day == 0 || day == 6) continue;
						trace ('  Creating class time for: $day');

						for (period in periods)
						{
							trace ('    and period: ${period.number}');
							var classTime = allCurrentClassTimes.filter(function (ct) return ct.schoolClassID == sc.id && ct.occurrence == occurrence).first();
							if (classTime == null) classTime = new ClassTime();
							classTime.day = day;
							classTime.occurrence = occurrence;
							classTime.linkedToNextPeriod = (period.number < 7);
							if (room != null) classTime.roomID = room.id;
							classTime.schoolClassID = sc.id;
							classTime.periodID = period.id;
							classTime.teacherID = rg.teacherID;
							classTime.save();

							occurrence++;
						}
					}

				}
				else {
					// Add a class time for form period only...
					var formPeriodNums = importConfig.schoolSetup.homeroom.periodNumbers;
					var formPeriods = [];
					for ( formPeriodNum in formPeriodNums ) {

						var formPeriod = periods.filter(function (p) return p.position==formPeriodNum).first();
						if (formPeriod == null) {
							trace ('Form Period Num: $formPeriodNum');
							trace ('Searching from periods: ${periods.map(function (p) return p.position)}');
							trace ('Searching from periods filtered: ${periods.filter(function (p) return p.position == formPeriodNum)}');
							throw ('Could not find form period');
						}
						else formPeriods.push( formPeriod );
					}

					// Delete all existing class times
					// We had some entered badly, and they weren't updating correctly.  This is an attempted workaround.
					ClassTime.manager.delete($schoolClassID == sc.id);

					// Add class times for each form period on each day
					var occurrence = 1;
					for (day in 0...7)
					{
						if (day == 0 || day == 6) continue;

						for ( formPeriod in formPeriods ) {
							var classTime = new ClassTime();
							trace ('  Creating class time for: $day');
							classTime.day = day;
							classTime.occurrence = occurrence;
							classTime.linkedToNextPeriod = false;
							classTime.roomID = room.id;
							classTime.schoolClassID = sc.id;
							classTime.periodID = formPeriod.id;
							classTime.teacherID = rg.teacherID;
							classTime.save();
							occurrence++;
						}
					}
				}

				// Enrol students
				var studentsInRollGroup = allCurrentStudents.filter(function (student) return student.rollGroupID == rg.id);
				for (s in studentsInRollGroup)
				{
					if ( s.active ) sc.students.add(s);
				}
			}
		}
	}

	public function doImportusersfromcsv()
	{
		var usersAndPasswords:Map<String, String> = new Map();
		var cwd = Sys.getCwd();
		var csvFileName = '${cwd}import/Users_${importConfig.schoolInfo.shortName}.csv';


		if (FileSystem.exists(csvFileName))
		{
			var file = sys.io.File.getContent(csvFileName);
			var lines = file.split('\n');
			for (line in lines)
			{
				var data = line.substr(10);
				var arr = data.split(",");
				var name = arr[0];
				var username = arr[1];
				var password = arr[2];
				var group = arr[3];

				if (username != null || password != null)
				{
					usersAndPasswords.set(username, password);
				}
				else
				{
					trace ('Failed to import user: $data');
				}
			}

			var countSuccess = 0;
			var countNotInMaze = 0;
			var countNotInCSV = 0;

			var dbUsers = User.manager.all();
			var allStudents = Student.manager.all();
			var allStudentProfiles = StudentProfile.manager.all();

			for (dbUser in dbUsers)
			{
				if ( !usersAndPasswords.exists(dbUser.username) )
				{
					trace ('Maze User `${dbUser.username}` was not in the password data');
					countNotInCSV++;
				}
				else
				{
					if ( dbUser.salt=="test" || dbUser.salt=="" )
					{
						dbUser.setPassword(usersAndPasswords.get(dbUser.username));
						dbUser.forcePasswordChange = false;
						dbUser.save();

						trace ('Saved user ${dbUser.username}');

						var student:Student = allStudents.filter( function(s) return s.person.user.id==dbUser.id ).first();
						if (student!=null) {
							var sp = allStudentProfiles.filter( function(sp) return sp.studentID==student.id ).first();
							sp.password = usersAndPasswords.get(dbUser.username);
							sp.save();
						}
					}

					countSuccess++;
				}
			}
			for (csvUser in usersAndPasswords.keys())
			{
				var matchedUsers = dbUsers.filter(function (u) {
					return u.username == csvUser;
				});
				if (matchedUsers.length == 0)
				{
					trace ('CSV User `${csvUser}` was not found in the Maze data');
					countNotInMaze++;
				}
			}
			trace ('$countSuccess passwords were synced successfully.');
			trace ('$countNotInCSV users were in Maze, but not on the server CSV');
			trace ('$countNotInMaze users were in the CSV, but not in Maze');
		}
		else {
			trace('No CSV file for passwords found: $csvFileName');
			trace('Default passwords will be used');
		}
	}

	public function doImportclassesandroomsmaze(qkey:String)
	{
		// Pull class lists from Maze transfer DB

		var cnx = connectToMazeTransferDB();

		trace ("Getting list of all current staff...");
		var sql = 'SELECT IDENT, SUBJ, THTQ.OCCUR, FREQ, T1TEACH, R1ROOM, QROW, QCOL, SHORTNAME, FULLNAME
					FROM `THTQ`
					     JOIN `SU` ON `SU`.`SUKEY` = SUBJ
					WHERE IDENT > 0 AND QKEY="$qkey"
					ORDER BY `THTQ`.`IDENT` DESC, `QCOL` ASC, `QROW` ASC';
		var rs = cnx.request(sql).results();
		var count = rs.count();
		trace ('  Found $count class times');

		cnx = connectToModelSchoolDB();

		// Collect data we'll be referring to

		var allCurrentSubjects = Subject.manager.all();
		var allCurrentStaff = StaffMember.manager.all();
		var allPeriods = Period.manager.all();

		// Build a hash of our current SchoolClass objects and their related ClassTime objects

		var allCurrentSchoolClasses = SchoolClass.manager.all();
		var allCurrentClassTimes = ClassTime.manager.all();
		var allCurrentRooms = Room.manager.all();
		var schoolClasses:Map<String, { sc:SchoolClass, scSaved:Bool, cts:Map<Int, MPair<ClassTime,Bool>>, row:Dynamic }> = new Map();
		for (sc in allCurrentSchoolClasses)
		{
			var classTimes = allCurrentClassTimes.filter(function (ct) return ct.schoolClassID == sc.id);
			var classTimesMap = new Map();
			for (ct in classTimes)
			{
				classTimesMap.set(ct.occurrence, new MPair(ct,false));
			}
			schoolClasses.set(sc.dbKey, { sc: sc, scSaved: false, cts: classTimesMap, row: null });
		}

		// Build a hash of all our Rooms

		var roomMap = new Map<String, Room>();
		for (r in allCurrentRooms)
		{
			roomMap.set(r.name, r);
		}


		// Go through the Maze data, create or update the rows.

		var occurrenceCount:Map<String, Int> = new Map();
		for (row in rs)
		{

			var dbKey = Std.string(row.IDENT); // one per school class

			// Skip any form classes...

			var thisPeriodPos:Int = row.QROW;
			for (p in importConfig.schoolSetup.homeroom.periodNumbers) {
				if (p == thisPeriodPos) {
					trace ('Skipping form class ... ${row.FULLNAME}');
					if ( schoolClasses.exists(dbKey) ) {
						// Delete an existing entry
						var scData = schoolClasses[dbKey];
						scData.sc.delete();
						trace ('  Deleted existing SchoolClass entry for this form class ${scData.sc}');
						for ( ct in scData.cts ) {
							if ( ct.a!=null && ct.a.id!=null ) {
								ct.a.delete();
								trace ('  Deleted existing ClassTime entry for this form class ${ct.a}');
							}
						}
						schoolClasses.remove( dbKey );
					}
					continue;
				}
			}

			// If it doesn't exist, occurrence is 1.  Otherwise, increment the occurrence

			var occurrence = occurrenceCount.exists(dbKey) ? occurrenceCount[dbKey] + 1 : 1;
			occurrenceCount[dbKey] = occurrence;

			var d;
			var sc:SchoolClass;
			var ctMap:Map<Int, MPair<ClassTime,Bool>>;
			var ct:ClassTime = null;

			var schoolClassAction:String;
			var classTimeAction:String;

			// Get SchoolClass from cache, or create and add to cache

			if (schoolClasses.exists(dbKey))
			{
				d = schoolClasses.get(dbKey);
				d.row = row;
				sc = d.sc;
				ctMap = d.cts;
				schoolClassAction = "Updated";
			}
			else
			{
				sc = new SchoolClass();
				ctMap = new Map();
				d = { sc: sc, scSaved: false, cts: ctMap, row: row };
				schoolClasses.set(dbKey, d);
				schoolClassAction = "Created";
			}

			// Get ClassTime from cache, or create and add to cache
			// Mark the flag in CTMap so we know the ClassTime is still in use, and we shouldn't delete it

			if (ctMap.exists(occurrence))
			{
				ct = ctMap[occurrence].a;
				ctMap[occurrence].b = true;
				classTimeAction = "Updated";
			}
			if (ct == null)
			{
				ct = new ClassTime();
				ctMap.set(occurrence, new MPair(ct,true));
				classTimeAction = "Created";
			}

			// Grab the teacher

			var teacher = allCurrentStaff.filter(function (sm) return sm.dbKey == row.T1TEACH).first();
			if (teacher == null)
			{
				// It is possible this is an empty class...
				var rs = getAllStudentsInClass(dbKey);

				// If the class has no students, skip this loop...
				if (rs.length == 0)
				{
					trace ('Skipping class $dbKey ${row.FULLNAME} because it had no students');
					schoolClasses.remove(dbKey);
					continue;
				}
				else
				{
					teacher = allCurrentStaff.filter(function (sm) return sm.dbKey == "nt").first();
				}
			}

			//
			// Set all the SchoolClass data
			//

			if (d.scSaved == false)
			{
				var subject = allCurrentSubjects.filter(function (sub) return sub.dbKey == row.SUBJ).first();

				if (subject == null) throw 'Could not find subject ${row.SUBJ} for class ${row.SHORTNAME} ${row.FULLNAME} ${dbKey}';

				sc.shortName = sanitiseString(row.SHORTNAME);
				sc.fullName = row.FULLNAME;
				if (sc.shortName == "") sc.shortName = sc.fullName;
				var foundYeargroup = "";
				if (subject.yeargroup != null)
				{
					sc.yeargroup = subject.yeargroup;
					sc.yeargroup2 = null;
					foundYeargroup = "Subject";
				}
				if (sc.yeargroup == null)
				{
					// Load all students, check which yeargroups they are in...
					var rs = getAllStudentsInClass(dbKey);
					if (rs.length > 0)
					{
						var tagsFound = [];
						for (row in rs)
						{
							if (tagsFound.has(row.TAG) == false)
								tagsFound.push(row.TAG);
						}

						if (tagsFound.length > 0)
						{
							foundYeargroup = "by first student";
							sc.yeargroup = Student.getYearFromTag(Std.parseInt(tagsFound[0]));
							if (tagsFound.length > 1)
							{
								sc.yeargroup2 = Student.getYearFromTag(Std.parseInt(tagsFound[1]));
							}
						}

						if (sc.yeargroup == null)
						{
							trace ("--- this subject has no apparent yeargroup... setting as null");
							foundYeargroup = "Did not find";
							sc.yeargroup = null;
							sc.yeargroup2 = null;
						}
					}
				}
				sc.frequency = row.FREQ;
				sc.dbKey = dbKey;
				sc.subject = subject;
				sc.save();
				d.scSaved = true;
				trace ('$schoolClassAction ${sc.shortName} ${sc.fullName} ${sc.yeargroupStr}');
			}

			//
			// Get or insert the room
			//

			var roomName:String = sanitiseString(row.R1ROOM);
			var room = allCurrentRooms.filter(function (r) return r.name == roomName).first();
			if (roomMap.exists(roomName))
			{
				room = roomMap.get(roomName);
			}
			else
			{
				room = new Room();
				room.name = roomName;
				room.save();
				roomMap.set(roomName, room);
				trace ('Created a new room [$roomName]');
			}

			//
			// Set all the classTime data
			// (If primary school doesn't use Maze timetables, we skip it here and fill them up in the rollgroupimport)
			//

			var isSecondarySchool = importConfig.schoolSetup.yeargroups.secondary.has(sc.yeargroup);

			if ( importConfig.features.primaryTimetables || isSecondarySchool )
			{
				var period = allPeriods.filter(function (p) return (p.position == row.QROW && p.yeargroups.has(sc.yeargroup))).first();
				var day = row.QCOL;
				// Check if the previous/next period is linked to this one
				ct.day = day;
				ct.occurrence = occurrence;
				ct.room = room;
				if (period == null)
				{
					trace ('Period was null while doing CTime for ${sc.fullName} (${sc.shortName}): $day pos(${row.QROW}) Y${sc.yeargroup} .... Skipping this classtime ($occurrence)');
					continue;
				}
				ct.period = period;
				ct.schoolClass = sc;
				ct.teacher = teacher;
				ct.save();
				trace ('  $classTimeAction CTime${sc.fullName}[${ct.occurrence}]: $day, ${period.name}, ${ct.teacher.dbKey}.');
			}
		}

		// End going through Maze rows
		// All SchoolClasses and ClassTimes have been saved.

		// Go through all existing classes, and their classTimes, and look for CTs that were not flagged,
		// these are no longer in Maze, so we should remove them.

		for ( sc in schoolClasses ) {
			for ( ctData in sc.cts ) {
				if ( !ctData.b ) {
					// Not saved, go ahead and delete it!
					var ct = ctData.a;
					trace ('  Deleted CTime${sc.sc.fullName}[${ct.occurrence}]: ${ct.day}, ${ct.period.name}, ${ct.teacher.dbKey}.');
					ctData.a.delete();
				}
			}
		}

		// Go through all CTs and look for linked periods, save as we go.

		for ( sc in schoolClasses ) {
			for ( ctData in sc.cts ) {
				var ct = ctData.a;
				if ( ct.period!=null ) {
					// If this is not the final occurance, check if a double period immediately follows
					if ( ct.occurrence<sc.sc.frequency ) {
						var nextCTData = sc.cts[ct.occurrence + 1];
						var nextCT = (nextCTData!=null) ? nextCTData.a : null;
						if ( nextCT!=null && nextCT.period!=null && nextCT.period.number!=null ) {
							var isSameDay = nextCT.day == ct.day;
							var isNextPeriod = (nextCT.period.number - 1) == ct.period.number;
							var linked = isSameDay && isNextPeriod;

							// Save only if the value is different from what's there already.
							if ( linked && ct.linkedToNextPeriod==false ) {
								ct.linkedToNextPeriod = true;
								ct.save();
							}
							else if ( !linked && ct.linkedToNextPeriod==true ) {
								ct.linkedToNextPeriod = false;
								ct.save();
							}

							if ( linked ) {
								trace ('${ct.period.name} flows into ${nextCT.period.name} for class ${sc.sc.fullName} on ${ct.day}');
							}
						}
					}
				}
				else trace ('For classtime $ct (schoolclass: [${sc.sc.dbKey}] ${sc.sc.fullName}, occurrence ${ct.occurrence}): period is null');
			}
		}
	}

	public function doAddjoinstudentclasses()
	{
		var allStudents = Student.manager.all();
		var allClasses = SchoolClass.manager.all();
		var total = 0;
		for (c in allClasses)
		{
			if (c.dbKey.startsWith("_rg") == false)
			{
				var rs = getAllStudentsInClass(c.dbKey);
				var students = rs.map(function (row) {
					return allStudents.filter(function (s) return s.dbKey == row.STKEY).first();
				});
				c.students.setList(students);

				var count = students.length;
				total += count;
				trace ('  Added $count students to class ${c.fullName} ${c.dbKey}');
			}
		}
		trace ('There are $total student/class relationships');
	}

	function importPeopleAndRollGroups()
	{
		this.doImportschoolhouses();
		this.doImportstaff();
		this.doImportrollgroups();
		this.doImportparents();
		this.doImportstudents();

		#if !QBC
			this.doImportusersfromcsv();
		#end
	}

	function importSubjectsClassesAndRollgroups()
	{
		this.doSubjects();
		#if ACBC
			this.doImportclassesandroomsmaze("2013S2"); // Still on 2013
		#elseif GBC
			this.doImportclassesandroomsmaze("Q2013S2"); // Still on 2013
		#elseif ABC
			this.doImportclassesandroomsmaze("2014S1");
		#else
			this.doImportclassesandroomsmaze("Q2014S1");
		#end

		this.doAddjoinstudentclasses();
		this.doSetuprollgroupsasclasses();
		this.doCleanuprollgroups();
	}

	public function doSetupfromscratch(confirm:String, username:String, password:String, firstName:String, lastName:String)
	{
		doRemovealluserdata(confirm);

		// Run Full import.
		// Only difference from partImport is that it changes the way periods are structured.
		// I don't do this nightly as a change here could break attendnace data.  So keep it to the start of Semester...

		importPeopleAndRollGroups();

		if (importConfig.features.primaryTimetables) {
			this.doImportmazeperiods("-1","12");
		}
		else {
			this.doCreatepsperiodsmanually(-1,6);
			this.doImportmazeperiods("7","12");
		}

		importSubjectsClassesAndRollgroups();
	}

	public function doRunpartimport()
	{
		importPeopleAndRollGroups();
		importSubjectsClassesAndRollgroups();
	}

	public function doRemovealluserdata(confirm:String)
	{
		if (confirm == "thisisdangerous")
		{
			Group.manager.delete(true);
			Permission.manager.delete(true);
			User.manager.delete(true);
			ClassTime.manager.delete(true);
			Department.manager.delete(true);
			Family.manager.delete(true);
			Person.manager.delete(true);
			Period.manager.delete(true);
			RollGroup.manager.delete(true);
			Room.manager.delete(true);
			SchoolClass.manager.delete(true);
			SchoolHouse.manager.delete(true);
			StaffMember.manager.delete(true);
			StaffMemberProfile.manager.delete(true);
			Student.manager.delete(true);
			StudentPhoto.manager.delete(true);
			StudentProfile.manager.delete(true);
			Subject.manager.delete(true);

			sys.db.Manager.cnx.request("DELETE FROM `_join_Department_StaffMember` WHERE 1");
			sys.db.Manager.cnx.request("DELETE FROM `_join_Group_User` WHERE 1");
			sys.db.Manager.cnx.request("DELETE FROM `_join_SchoolClass_Student` WHERE 1");
		}
		else throw "Please type 'thisisdangerous' into the confirm field if you really want to break everything ever.";
	}

	function sanitiseString(str:String)
	{
		return (str == null) ? "" : Utf8.encode(str);
	}

	function getAllStudentsInClass(mazeIdent:String, ?debug=false):List<Dynamic>
	{
		var oldCnx = sys.db.Manager.cnx;
		var cnx = connectToMazeTransferDB();
		var sql = 'SELECT SF.SFKEY, ST.STKEY, ST.SURNAME, ST.FIRST_NAME, ST.PREF_NAME, ST.GENDER, ST.TAG, ST.ROLL_GROUP
			FROM ((((TTTG INNER JOIN STMA ON TTTG.IDENT = STMA.IDENT)
			      LEFT JOIN SF ON TTTG.T1TEACH = SF.SFKEY)
			      INNER JOIN ST ON STMA.SKEY = ST.STKEY)
			      INNER JOIN SU ON STMA.MKEY = SU.SUKEY)
			WHERE (TTTG.HROW >= "0")
			      AND (TTTG.IDENT = "$mazeIdent")
			      AND (ST.STATUS = "FULL")
			ORDER BY SU.SUKEY ASC, TTTG.CLASS ASC, ST.STKEY ASC';
		if (debug) trace (sql);
		var rs = cnx.request(sql).results();
		sys.db.Manager.cnx = oldCnx;
		return rs;
	}

	function connectToMazeTransferDB()
	{
		sys.db.Manager.cnx = this.mazeCnx;
		return this.mazeCnx;
	}

	function connectToModelSchoolDB()
	{
		sys.db.Manager.cnx = this.modelSchoolCnx;
		return this.modelSchoolCnx;
	}

	function getUserIfExists(userToSave:User)
	{
		var u = User.manager.select($username == userToSave.username);
	}
}
