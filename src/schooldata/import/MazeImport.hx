package tasks;
import app.coredata.model.*;
import ufront.auth.model.*;
import app.student.model.Note;
import app.attendance.model.*;
import app.coredata.model.Person.Gender;
import haxe.ds.StringMap;
import haxe.Utf8;
import sys.FileSystem;
import ufront.tasks.TaskSet;
using tink.CoreApi;
using StringTools;
using Lambda;

@name("Import Maze Data")
@description("Will import the Maze data.")
class MazeImport extends TaskSet 
{
	@description("Import Student Data")
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

		var cnx = connectToSMS();

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

		var mazeKeysNotFound = allCurrentStudents.map( function(s) return s.mazeKey );

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
			var mazeKey:String = cast row.STKEY;

			mazeKeysNotFound.remove( mazeKey );

			var action = "";
			s = allCurrentStudents.filter(function (s) { return s.mazeKey == mazeKey; }).first();
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
			var family = allCurrentFamilies.filter(function (fam) return fam.mazeKey == row.FAMILY).first();
			var schoolHouse = allCurrentSchoolHouses.filter(function (sh) return sh.shortName == row.HOUSE).first();
			if (s.graduatingYear != graduatingYear
				|| s.mazeKey != row.STKEY
				|| s.personID != p.id
				|| s.rollGroupID != rollGroup.id
				|| s.schoolHouseID != schoolHouse.id
				|| s.familyID != family.id
				|| s.active != true
				)
			{
				s.graduatingYear = graduatingYear;
				s.mazeKey = row.STKEY;
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

				if (family != null)
				{
					s.familyID = family.id;
				}
				else trace ("Family not found: " + row.FAMILY);
				
				s.save();
			}

			// StudentPhoto;
			sPhoto.photo = row.STUDENT_PIC;
			if (sPhoto.photo != null)
			{
				var mazePhotoMap = haxe.crypto.Md5.encode(sPhoto.photo.toHex());
				if (mazePhotoMap != sPhoto.hash) 
				{
					sPhoto.student = s;
					sPhoto.hash = mazePhotoMap;
					sPhoto.save();
				}
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
			
			trace ('$action ${p.firstName} ${p.surname} ${u.username} ${s.mazeKey} ($i/$count)');
		}

		for ( mazeKey in mazeKeysNotFound ) {
			var s = allCurrentStudents.filter(function (s) { return s.mazeKey == mazeKey; }).first();
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

	static var usernameCorrections = [
		#if ACBC
			"DOSS" => "sdossantos"
		#elseif GBC
			"MMA" => "mkucic",
			"JAN" => "jandrew"
		#else
			"JASONONEIL" => "joneil"
		#end
	];

	@help("Import Staff Data")
	public function doImportstaff() 
	{
		var cnx = connectToMazeTransferDB();

		trace ("Getting list of all current staff...");
		var sql = "SELECT * FROM `SF`";
		var rs = cnx.request(sql).results();
		var count = Lambda.count(rs);
		trace ('  Found $count staff');

		var cnx = connectToSMS();

		var allCurrentStaff = StaffMember.manager.all();
		var allCurrentPeople = Person.manager.all();
		var allCurrentUsers = User.manager.all();
		var allCurrentProfiles = StaffMemberProfile.manager.all();

		var staffGroup = Group.manager.select($name == "staff");
		var teachersGroup = Group.manager.select($name == "teachers");
		var usersGroup = Group.manager.select($name == "users");
		var nonTeachingStaffGroup = Group.manager.select($name == "nonTeachingStaff");

		var testPassword = User.generatePasswordHash("test", "test");
		var domain = switch (AppConfig.appShortName) {
			case "QBC": "qbcol.com.au";
			case "GBC": "geelongbc.org";
			case "ACBC": "acbc.wa.edu.au";
			case "ABC": "alkimosbc.wa.edu.au";
			default: "example.org";
		};


		var i = 0;
		for (row in rs)
		{
			i++;
			var s:StaffMember;
			var p:Person;
			var u:User;
			var sProfile:StaffMemberProfile;

			// Check if the rows already exist
			var mazeKey:String = cast row.SFKEY;

			var action:String;
			s = allCurrentStaff.filter(function (s) { return s.mazeKey == mazeKey; }).first();
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
			if (email == null) email = 'unknownuser_$mazeKey@$domain';
			var username:String;
			if ( usernameCorrections.exists(mazeKey) ) {
				username = usernameCorrections[mazeKey];
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
				|| s.mazeKey != mazeKey
				|| s.active != active )
			{
				s.active = active;
				s.person = p;
				s.title = sanitiseString(row.TITLE);
				s.mazeKey = mazeKey;
				s.save();
			}

			// StaffProfile
			sProfile.registration = sanitiseString(row.REGISTRATION);
			sProfile.registrationExpiry = row.REGO_EXPIRY; // date
			sProfile.wwcc = sanitiseString(row.WWW_CHECK);
			sProfile.wwccExpiry = row.WWW_EXPIRY_DATE; // Date
			sProfile.policeClearance = (row.POLICE_CLEARANCE == "Y");
			sProfile.policeClearanceDate = row.CLEARANCE_DATE; // date
			sProfile.mobile = sanitiseString(row.MOBILE);
			sProfile.email = sanitiseString(row.SF_EMAIL);
			sProfile.staffMember = s;
			sProfile.save();

			trace ('$action ${p.firstName} ${p.surname} ${u.username} ${s.mazeKey} ($i/$count)');
		}

		// Create a staff member called "No Teacher"
		var noTeacherStaffMember:StaffMember = allCurrentStaff.filter(function (s) { return s.mazeKey == "nt"; }).first();
		if (noTeacherStaffMember == null)
		{
			noTeacherStaffMember = new StaffMember();
			var noTeacherP = new Person();
			var noTeacherU = new User("noteacher", "test123");
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
			noTeacherStaffMember.mazeKey = "nt";
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

	@help("Import Parent and Family Data")
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

		var cnx = connectToSMS();

		var allCurrentFamilies = Family.manager.all();
		var allCurrentHomes = Home.manager.all();

		var i = 0;
		for (r in homeRows)
		{
			var row:Dynamic = r;
			i++;
			var action:String;
			var h:Home = allCurrentHomes.filter(function (home) return home.mazeKey == row.UMKEY).first();
			if (h == null) 
			{
				action = "Created";
				h = new Home();
				allCurrentHomes.push( h );
			}
			else action = "Updated";

			h.mazeKey = row.UMKEY;
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
			trace ('$action Home ${h.mazeKey} ($i/$homeCount)');
		}

		var i = 0;
		for (r in familyRows)
		{
			var row:Dynamic = r;
			i++;
			var action:String;
			var f:Family = allCurrentFamilies.filter(function (fam) return fam.mazeKey == row.DFKEY).first();
			if (f == null) 
			{
				action = "Created";
				f = new Family();
			}
			else action = "Updated";

			var familySurname = sanitiseString(row.SURNAME);
			var motherFirstName = sanitiseString(row.MNAME);
			var motherSurname = sanitiseString(row.MSURNAME);
			var fatherFirstName = sanitiseString(row.FNAME);
			var fatherSurname = sanitiseString(row.FSURNAME);

			var motherName = (motherSurname != "") ? '$motherFirstName $motherSurname' : '$motherFirstName $familySurname';
			var fatherName = (fatherSurname != "") ? '$fatherFirstName $fatherSurname' : '$fatherFirstName $familySurname';

			f.mazeKey = row.DFKEY;
			f.motherName = motherName;
			f.motherMobile = sanitiseString(row.MMOBILE);
			f.motherWorkPhone = sanitiseString(row.MBUS_PHONE);
			f.motherEmail = sanitiseString(row.M_EMAIL);
			f.fatherName = fatherName;
			f.fatherMobile = sanitiseString(row.FMOBILE);
			f.fatherWorkPhone = sanitiseString(row.FBUS_PHONE);
			f.fatherEmail = sanitiseString(row.F_EMAIL);

			f.homeTitle = sanitiseString(row.HOMETITLE);
			f.mailTitle = sanitiseString(row.MAILTITLE);
			f.billingTitle = sanitiseString(row.BILLINGTITLE);

			function getHome( mazeKey:String ) {
				return allCurrentHomes.filter( function (h) return h.mazeKey==mazeKey ).first();
			}

			f.homeAddress = getHome( row.HOMEKEY );
			f.mailAddress = getHome( row.MAILKEY );
			f.billingAddress = getHome( row.BILLINGKEY );

			f.save();
			trace ('$action Family ${f.mazeKey} ${f.motherName} ${f.fatherName} ($i/$familyCount)');
		}
	}

	@help("Import Roll Groups")
	public function doImportrollgroups() 
	{
		var cnx = connectToMazeTransferDB();
		trace ("Getting list of all roll groups...");
		var sql = "SELECT * FROM `KGC`";
		var rs = cnx.request(sql).results();
		var count = rs.count();
		trace ('  Found $count roll groups');

		var cnx = connectToSMS();

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
			var teacherMazeKey = sanitiseString(row.TEACHER);
			var teacher = allCurrentTeachers.filter(function (t) return t.mazeKey == teacherMazeKey).first();
			if (teacher == null) trace ('Teacher $teacherMazeKey not found for roll group $name');
			else r.teacher = teacher;

			// yeagroup
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

	@help("Clean up rollgroups")
	public function doCleanuprollgroups() 
	{
		var allSchoolClasses = SchoolClass.manager.all();

		for (sc in allSchoolClasses)
		{
			var needsDeleting = false;

			#if QBC 
				var rogueSecondaryFormClass = sc.fullName.startsWith("FORM ");
				var duplicatePrimaryFormClass = sc.mazeKey.startsWith("_rg") && !sc.mazeKey.startsWith("_rgY") && sc.yeargroup<7;
				needsDeleting = rogueSecondaryFormClass || duplicatePrimaryFormClass;
			#elseif ACBC
				var mazeFormClass = sc.fullName.indexOf('Form')>-1 && sc.mazeKey.startsWith("_rg")==false;
				// If each class time falls outside of the periods labelled "FORM", then it's not a form period.  Maybe it's an assembly etc
				var notInFormPeriod = sc.classTimes.foreach( function (ct) return ct.period.name.indexOf("FORM")>-1 );
				needsDeleting = (mazeFormClass&&notInFormPeriod);
			#end 

			if ( needsDeleting ) {
				trace ('Deleting $sc (${sc.mazeKey} ${sc.fullName}) with ClassTimes ${sc.classTimes}');
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

	@help("Import School Houses")
	public function doImportschoolhouses() 
	{
		var cnx = connectToMazeTransferDB();
		trace ("Getting list of all School Houses...");
		var sql = "SELECT * FROM `KGH`";
		var rs = cnx.request(sql).results();
		var count = rs.count();
		trace ('  Found $count School Houses');

		var cnx = connectToSMS();

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

	@help("Import Subjects")
	public function doSubjects()
	{
		var cnx = connectToMazeTransferDB();

		trace ("Getting list of all current staff...");
		var sql = "SELECT * FROM `SU`";
		var rs = cnx.request(sql).results();
		var count = rs.count();
		trace ('  Found $count subjects');

		var cnx = connectToSMS();

		var allCurrentSubjects = Subject.manager.all();
		var allCurrentStaff = StaffMember.manager.all();

		var i = 0;
		for (row in rs)
		{
			i++;
			var s:Subject;

			// Check if the rows already exist, create it if not
			var mazeKey:String = row.SUKEY;
			s = allCurrentSubjects.filter(function (s) { return s.mazeKey == mazeKey; }).first();
			var action = (s == null) ? "Created" : "Updated";
			
			if (s == null) s = new Subject();
			s.name = sanitiseString(row.FULLNAME);
			s.mazeKey = mazeKey;

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
					var teacher = allCurrentStaff.filter(function (staff) { return staff.mazeKey == teacherMazeID; }).first();
					if (teacher != null) s.contactTeacher = teacher;
				}
			}

			row.CURR_OFFERED; // Not sure if this is relevant
			row.SEMESTER; // Seems to be 0,1,2,3 ... not sure what they mean

			s.save();
			trace ('$action ${s.name} ${s.yeargroup} ${s.mazeKey} ($i/$count)');
		}
	}

	@help("Create periods 1,R,2,L,3 for the yeargroups specified")
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

	@help("Delete existing periods... not implemented yet")
	public function doDeleteperiods(fromYear:String, toYear:String)
	{
		throw "Not implemented";
	}

	@help("Import Periods from Maze for the yeargroups specified")
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

		var cnx = connectToSMS();

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

	@help("Import RollGroups as SchoolClasses and Class Times for Those")
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
			var isPrimarySchool = AppConfig.primaryYears().has(rg.yeargroup);
			var mazeKey = "_rg" + rg.name;
			rg.yeargroup = (rg.yeargroup == null) ? 1 : rg.yeargroup;
			trace ('Working on Rollgroup: $mazeKey (Yr ${rg.yeargroup})');
			
			// Get or create suShortbject
			var su = allCurrentSubjects.filter(function (su) return su.mazeKey == mazeKey).first();
			if (su == null) su = new Subject();
			su.mazeKey = mazeKey;
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
				// FIXME!!! Just use a default room for now
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
				var sc = allCurrentSchoolClasses.filter(function (sc) return sc.mazeKey == mazeKey).first();
				if (sc == null) sc = new SchoolClass();
				sc.shortName = rg.name;
				sc.fullName = rg.description;
				sc.yeargroup = rg.yeargroup;
				sc.yeargroup2 = rg.yeargroup2;
				sc.frequency = isPrimarySchool ? periods.length*5 : 5;
				sc.mazeKey = mazeKey;
				sc.subjectID = su.id;
				sc.save();
				trace (' School Class created with ID ${sc.id}');

				// Set up the class times
				if ( isPrimarySchool && AppConfig.features.primaryTimetables==false ) {
					// Add class times for every period of the day
					var occurence = 1;
					for (day in 0...7)
					{
						if (day == 0 || day == 6) continue;
						trace ('  Creating class time for: $day');

						for (period in periods)
						{
							trace ('    and period: ${period.number}');
							var classTime = allCurrentClassTimes.filter(function (ct) return ct.schoolClassID == sc.id && ct.occurence == occurence).first();
							if (classTime == null) classTime = new ClassTime();
							classTime.day = day;
							classTime.occurence = occurence;
							classTime.linkedToNextPeriod = (period.number < 7);
							if (room != null) classTime.roomID = room.id;
							classTime.schoolClassID = sc.id;
							classTime.periodID = period.id;
							classTime.teacherID = rg.teacherID;
							classTime.save();

							occurence++;
						}
					}

				}
				else {
					// Add a class time for form period only...
					var formPeriodNums = AppConfig.formPeriodNums();
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
					var occurence = 1;
					for (day in 0...7)
					{
						if (day == 0 || day == 6) continue;

						for ( formPeriod in formPeriods ) {
							var classTime = new ClassTime();
							trace ('  Creating class time for: $day');
							classTime.day = day;
							classTime.occurence = occurence;
							classTime.linkedToNextPeriod = false;
							classTime.roomID = room.id;
							classTime.schoolClassID = sc.id;
							classTime.periodID = formPeriod.id;
							classTime.teacherID = rg.teacherID;
							classTime.save();
							occurence++;
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

	@help("Import User Passwords")
	@description("Have a CSV in out/import/Users.csv, the file is a concatanation of makestaffaccounts.log and makestudentaccounts.log from the student server.")
	public function doImportusersfromcsv()
	{
		var usersAndPasswords:Map<String, String> = new Map();
		var cwd = Sys.getCwd();
		var csvFileName = '${cwd}import/Users_${AppConfig.appShortName}.csv';


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
			var allPeople = Person.manager.all();
			var allStudentProfiles = StudentProfile.manager.all();

			for (dbUser in dbUsers)
			{
				var isStudent = (dbUser.username.indexOf("20") > -1);
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
				if (dbUsers.filter(function (u) return u.username == csvUser).length == 0)
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

	@help("Import Room, SchoolClass and ClassTime data from Maze")
	@description("Qkey is the semester key in Maze, eg: Q2013S1 for QBC & ABC, 2012S2 for ACBC")
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

		cnx = connectToSMS();

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
				classTimesMap.set(ct.occurence, new MPair(ct,false));
			}
			schoolClasses.set(sc.mazeKey, { sc: sc, scSaved: false, cts: classTimesMap, row: null });
		}

		// Build a hash of all our Rooms

		var roomMap = new Map<String, Room>();
		for (r in allCurrentRooms)
		{
			roomMap.set(r.name, r);
		}


		// Go through the Maze data, create or update the rows.
		
		var occurenceCount:Map<String, Int> = new Map(); 
		for (row in rs)
		{

			var mazeKey = Std.string(row.IDENT); // one per school class

			// Skip any form classes...

			var thisPeriodPos:Int = row.QROW;
			for (p in AppConfig.formPeriodNums()) {
				if (p == thisPeriodPos) {
					trace ('Skipping form class ... ${row.FULLNAME}');
					if ( schoolClasses.exists(mazeKey) ) {
						// Delete an existing entry
						var scData = schoolClasses[mazeKey];
						scData.sc.delete();
						trace ('  Deleted existing SchoolClass entry for this form class ${scData.sc}');
						for ( ct in scData.cts ) {
							if ( ct.a!=null && ct.a.id!=null ) {
								ct.a.delete();
								trace ('  Deleted existing ClassTime entry for this form class ${ct.a}');
							}
						}
						schoolClasses.remove( mazeKey );
					}
					continue;	
				}
			}

			// If it doesn't exist, occurence is 1.  Otherwise, increment the occurence

			var occurence = occurenceCount.exists(mazeKey) ? occurenceCount[mazeKey] + 1 : 1;
			occurenceCount[mazeKey] = occurence;

			var d;
			var sc:SchoolClass;
			var ctMap:Map<Int, MPair<ClassTime,Bool>>;
			var ct:ClassTime = null;

			var schoolClassAction:String;
			var classTimeAction:String;

			// Get SchoolClass from cache, or create and add to cache

			if (schoolClasses.exists(mazeKey))
			{
				d = schoolClasses.get(mazeKey);
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
				schoolClasses.set(mazeKey, d);
				schoolClassAction = "Created";
			}

			// Get ClassTime from cache, or create and add to cache
			// Mark the flag in CTMap so we know the ClassTime is still in use, and we shouldn't delete it

			if (ctMap.exists(occurence))
			{
				ct = ctMap[occurence].a;
				ctMap[occurence].b = true; 
				classTimeAction = "Updated";
			}
			if (ct == null) 
			{
				ct = new ClassTime();
				ctMap.set(occurence, new MPair(ct,true));
				classTimeAction = "Created";
			}

			// Grab the teacher

			var teacher = allCurrentStaff.filter(function (sm) return sm.mazeKey == row.T1TEACH).first();
			if (teacher == null) 
			{
				// It is possible this is an empty class...
				var rs = getAllStudentsInClass(mazeKey);

				// If the class has no students, skip this loop...
				if (rs.length == 0) 
				{
					trace ('Skipping class $mazeKey ${row.FULLNAME} because it had no students');
					schoolClasses.remove(mazeKey);
					continue;
				}
				else
				{
					teacher = allCurrentStaff.filter(function (sm) return sm.mazeKey == "nt").first();
				}
			}

			//
			// Set all the SchoolClass data
			//

			if (d.scSaved == false)
			{
				var subject = allCurrentSubjects.filter(function (sub) return sub.mazeKey == row.SUBJ).first();

				if (subject == null) throw 'Could not find subject ${row.SUBJ} for class ${row.SHORTNAME} ${row.FULLNAME} ${mazeKey}';
				
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
					var rs = getAllStudentsInClass(mazeKey);
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
				sc.mazeKey = mazeKey;
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

			var isSecondarySchool = 
				#if ABC 
					// so many of ABC's are 0 that I need to import them...
					AppConfig.secondaryYears().has(sc.yeargroup) || sc.yeargroup==0
				#else 
					AppConfig.secondaryYears().has(sc.yeargroup)
				#end
			; 

			if ( AppConfig.features.primaryTimetables || isSecondarySchool )
			{
				var period = allPeriods.filter(function (p) return (p.position == row.QROW && p.yeargroups.has(sc.yeargroup))).first();
				var day = row.QCOL;
				// Check if the previous/next period is linked to this one
				ct.day = day;
				ct.occurence = occurence;
				ct.room = room;
				if (period == null)
				{
					trace ('Period was null while doing CTime for ${sc.fullName} (${sc.shortName}): $day pos(${row.QROW}) Y${sc.yeargroup} .... Skipping this classtime ($occurence)');
					continue;
				}
				ct.period = period;
				ct.schoolClass = sc;
				ct.teacher = teacher;
				ct.save();
				trace ('  $classTimeAction CTime${sc.fullName}[${ct.occurence}]: $day, ${period.name}, ${ct.teacher.mazeKey}.');
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
					trace ('  Deleted CTime${sc.sc.fullName}[${ct.occurence}]: ${ct.day}, ${ct.period.name}, ${ct.teacher.mazeKey}.');
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
					if ( ct.occurence<sc.sc.frequency ) {
						var nextCTData = sc.cts[ct.occurence + 1];
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
				else trace ('For classtime $ct (schoolclass: [${sc.sc.mazeKey}] ${sc.sc.fullName}, occurence ${ct.occurence}): period is null');
			}
		}
	}

	@help("Add Class<->Student")
	@description("Adds the information about which students are enrolled in which classes")
	public function doAddjoinstudentclasses()
	{
		var allStudents = Student.manager.all();
		var allClasses = SchoolClass.manager.all();
		var total = 0;
		for (c in allClasses)
		{
			if (c.mazeKey.startsWith("_rg") == false)
			{
				var rs = getAllStudentsInClass(c.mazeKey);
				var students = rs.map(function (row) {
					return allStudents.filter(function (s) return s.mazeKey == row.STKEY).first();
				});
				c.students.setList(students);
				
				var count = students.length;
				total += count;
				trace ('  Added $count students to class ${c.fullName} ${c.mazeKey}');
			}
		}
		trace ('There are $total student/class relationships');
	}

	@help("Reload cache")
	public function doReloadcoredatacache()
	{
		trace ("Removing existing cache file");
		var cacheFile = Sys.getCwd() + "cache/coredata_" + AppConfig.appShortName + ".ds";
		if ( FileSystem.exists(cacheFile) ) {
			FileSystem.deleteFile( cacheFile );
			trace ("Done... it will be recreated on next page load");
		}
		else trace ("Did not exist.  It will be created on the next page load");
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

	@help("Run Full Import. Will update everything, but reset periods, classes etc. Use at start of Semester.")
	public function doSetupfromscratch(confirm:String, username:String, password:String, firstName:String, lastName:String)
	{
		doRemovealluserdata(confirm);

		var authTasks = new AuthTasks();
		authTasks.doSetupsmsgroups();
		authTasks.doCreateuser(username,password,firstName,lastName);
		authTasks.doCreateuser("guest","redrose22","Guest","Account");
		authTasks.doAddusertogroup(username,"superusers");

		// Run Full import.
		// Only difference from partImport is that it changes the way periods are structured.
		// I don't do this nightly as a change here could break attendnace data.  So keep it to the start of Semester...

		importPeopleAndRollGroups();

		if ( AppConfig.features.primaryTimetables ) {
			this.doImportmazeperiods("-1","12");
		}
		else {
			this.doCreatepsperiodsmanually(-1,6);
			this.doImportmazeperiods("7","12");
		}
		
		importSubjectsClassesAndRollgroups();
		this.doReloadcoredatacache();
	}

	@help("Run part import. Will update students, staff, class enrolments. Will not change classes or periods.")
	public function doRunpartimport()
	{
		new AuthTasks().doSetupsmsgroups();
		importPeopleAndRollGroups();
		importSubjectsClassesAndRollgroups();
		doReloadcoredatacache();
	}

	@help("Remove all user data")
	@description("If you really want to do this please type 'thisisdangerous' into the confirm field")
	public function doRemovealluserdata(confirm:String)
	{
		if (confirm == "thisisdangerous")
		{
			AttendanceDetails.manager.delete(true);
			AttendanceEvent.manager.delete(true);
			AttendanceRecord.manager.delete(true);
			Group.manager.delete(true);
			Permission.manager.delete(true);
			User.manager.delete(true);
			ClassTime.manager.delete(true);
			CurriculumNote.manager.delete(true);
			DayAttendanceSummary.manager.delete(true);
			Department.manager.delete(true);
			Family.manager.delete(true);
			OutOfClassRecord.manager.delete(true);
			PastoralCareNote.manager.delete(true);
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
			
			sys.db.Manager.cnx.request("DELETE FROM `_join_AttendanceEvent_Student` WHERE 1");
			sys.db.Manager.cnx.request("DELETE FROM `_join_Department_StaffMember` WHERE 1");
			sys.db.Manager.cnx.request("DELETE FROM `_join_Group_User` WHERE 1");
			sys.db.Manager.cnx.request("DELETE FROM `_join_SchoolClass_Student` WHERE 1");
		}
		else throw "Please type 'thisisdangerous' into the confirm field if you really want to break everything ever.";
	}

	@help("Swap periods over.... ACBC only for now")
	public function doSwapPeriods()
	{
		var periods = Period.manager.all();
		var i = 0;
		for ( p in periods ) {
			
			if ( i<5 ) p.yeargroupsStr = "-1,0,1,2,3,4,5,6"; // Primary 
			else p.yeargroupsStr = "7,8,9,10,11,12"; // Secondary

			p.save();

			i++;
			trace ( 'Changed $p.yeargroups to ${p.yeargroups}' );
		}
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
		cnx.close();
		sys.db.Manager.cnx = oldCnx;
		return rs;
	}

	function connectToMazeTransferDB()
	{
		var cnx = sys.db.Mysql.connect(MySQLConfig.mazeImport);
		sys.db.Manager.cnx = cnx;
		return cnx;
	}

	function connectToSMS()
	{
		var cnx = sys.db.Mysql.connect(MySQLConfig.mainSiteDB);
		sys.db.Manager.cnx = cnx;
		return cnx;
	}

	function getUserIfExists(userToSave:User)
	{
		var u = User.manager.select($username == userToSave.username);
	}
}