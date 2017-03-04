import sys.db.*;
import haxe.Utf8;
import modelschool.core.imports.MazeImport;
import modelschool.core.api.DatabaseSetupApi;

class Test {
	static function main() {
		var mazeCnx = Mysql.connect({
			host: 'db_1',
			user: 'root',
			pass: 'root',
			database: 'modelschool_test_maze1'
		});
		var modelSchoolCnx = Mysql.connect({
			host: 'db_1',
			user: 'root',
			pass: 'root',
			database: 'modelschool'
		});

		sys.db.Manager.cnx = modelSchoolCnx;

		// Set up the modelschool database tables.
		var api = new DatabaseSetupApi();
		api.setupDatabase();

		// Set up a mazeimport
		var mazeImporter = new MazeImport({
			schoolInfo: {
				shortName: 'MTS',
				domain: 'mazetestschool.edu'
			},
			schoolSetup: {
				yeargroups: {
					primary: [0, 1, 2, 3, 4, 5, 6],
					secondary: [7, 8, 9, 10, 11, 12]
				},
				homeroom: {
					periodNumbers: [1]
				}
			},
			features: {
				primaryTimetables: false
			},
			usernameCorrections: new Map()
		}, mazeCnx, modelSchoolCnx);

		mazeImporter.doSetupfromscratch('admin', 'pass', 'Admin', 'User');
	}
}
