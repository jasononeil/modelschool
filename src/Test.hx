import sys.db.*;
import haxe.Utf8;
import modelschool.core.imports.MazeImport;

class Test {
	static function main() {
		Manager.cnx = Mysql.connect({
			host: 'db_1',
			user: 'root',
			pass: 'root',
			database: 'modelschool_test_maze1'
		});
		var studentResults = Manager.cnx.request('SELECT first_name, pref_name, surname FROM ST WHERE status="FULL"');
		for (s in studentResults.results()) {
			var s = Utf8.encode(Std.string(s));
			Sys.println('$s<br>');
		}
	}
}
