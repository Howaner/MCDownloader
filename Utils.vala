class Utils {
	
	public static OS get_os() {
		return OS.LINUX;
	}
	
	public static string check_windows_path(string path) {
		if (get_os() != OS.WINDOWS) return path;
		string newPath = path.replace("/", "\\");
		return newPath;
	}
	
	public static Gee.List<DownloadItem>? get_assets_files(Xml.Node* root_node) {
		string folder = Downloader.instance.folder;
		Gee.List<DownloadItem>? items = new Gee.ArrayList<DownloadItem>();
		try {
			for (Xml.Node* node = root_node->children; node != null; node = node->next) {
				if (node->type != Xml.ElementType.ELEMENT_NODE) continue;
				if (node->name != "Contents") continue;
				string filename = "";
				int size = 0;
				for (Xml.Node* mini_node = node->children; mini_node != null; mini_node = mini_node->next) {
					if (mini_node->type != Xml.ElementType.ELEMENT_NODE) continue;
					string content_name = mini_node->name;
					if (content_name == "Key") filename = mini_node->get_content();
					if (content_name == "Size") size = int.parse(mini_node->get_content());
				}
				if (filename.substring(filename.index_of_nth_char(filename.length-1), 1) == "/") continue;
				string file_string = check_windows_path("%s/assets/%s".printf(folder, filename));
				DownloadItem dl_item = new DownloadItem("https://s3.amazonaws.com/Minecraft.Resources/%s".printf(filename), file_string);
				items.add(dl_item);
			}
			
			return items;
		} catch (Error e) {
			print(e.message + "\n");
			return null;
		}
	}
	
	public static Gee.List<string>? get_versions() {
		Json.Object? root_object = load_json("https://s3.amazonaws.com/Minecraft.Download/versions/versions.json");
		if (root_object == null) return null;
		Gee.List<string> versions = new Gee.ArrayList<string>();
		
		var versions_object = root_object.get_array_member("versions");
		versions_object.get_elements().foreach((version_node) => {
			var version_object = version_node.get_object();
			string id = version_object.get_string_member("id");
			versions.add(id);
		});
		return versions;
	}
	
	public static Gee.List<DownloadItem>? get_version_files(string version) {
		Gee.List<DownloadItem> items = new Gee.ArrayList<DownloadItem>();
		string json_file = check_windows_path("%s/versions/%s/%s.json".printf(Downloader.instance.folder, version, version));
		var parser = new Json.Parser();
		try {
			parser.load_from_file(json_file);
		} catch (Error e) {
			return null;
		}
		var root_object = parser.get_root().get_object();
		
		var libraries_object = root_object.get_array_member("libraries");
		libraries_object.get_elements().foreach((librarie_node) => {
			var librarie_object = librarie_node.get_object();
			string librarie_name = librarie_object.get_string_member("name");
			string librarie_url = get_librarie_url(librarie_name);
			string librarie_path = get_librarie_path(librarie_name);
			bool cancel = false;
			if (librarie_object.has_member("natives")) {
				var native_object = librarie_object.get_object_member("natives");
				if (native_object.has_member(get_os().get_json_name())) {
					string native = native_object.get_string_member(get_os().get_json_name());
					librarie_url = librarie_url.replace(".jar", "-" + native + ".jar");
					librarie_path = librarie_path.replace(".jar", "-" + native + ".jar");
				} else
					cancel = true;
			}
			if (cancel)
				print("-> Überspringe Native %s!\n".printf(librarie_name));
			else
				items.add(new DownloadItem(librarie_url, librarie_path));
		});
		items.add(new DownloadItem("https://s3.amazonaws.com/Minecraft.Download/versions/%s/%s.jar".printf(version, version), "%s/versions/%s/%s.jar".printf(Downloader.instance.folder, version, version)));
		items.add(new DownloadItem("https://s3.amazonaws.com/Minecraft.Download/versions/%s/minecraft_server.%s.jar".printf(version, version), "%s/versions/%s/minecraft_server.%s.jar".printf(Downloader.instance.folder, version, version)));
		return items;
	}
	
	public static Json.Object? load_json(string url) {
		try {
			File file = File.new_for_uri(url);
			FileInputStream @is = file.read(null);
			var parser = new Json.Parser();
			parser.load_from_stream(@is);
			var root_object = parser.get_root().get_object();
			return root_object;
		} catch (Error e) {
			print(e.message + "\n");
			return null;
		}
	}
	
	public static string get_librarie_url(string librarie) {
		string[] s = librarie.split(":");
		string package = s[0].replace(".", "/");
		string name = s[1];
		string version = s[2];
		string url = "https://s3.amazonaws.com/Minecraft.Download/libraries/%s/%s/%s/%s.jar".printf(package, name, version, name + "-" + version);
		return url;
	}
	
	public static string get_librarie_path(string librarie) {
		string[] s = librarie.split(":");
		string package = s[0].replace(".", "/");
		string name = s[1];
		string version = s[2];
		string path = check_windows_path("%s/libraries/%s/%s/%s/%s.jar".printf(Downloader.instance.folder, package, name, version, name + "-" + version));
		return path;
	}
	
	public static int get_prozent(int wert, int gesamt) {
		float prozent = (float) wert / gesamt * 100;
		return (int) prozent;
	}
	
	public static void check_path(string path) {
		File file = (File.new_for_path(path)).get_parent();
		if (file.query_exists()) return;
		try {
			file.make_directory_with_parents();
		} catch (Error e) {
			print(e.message);
		}
	}
	
}

enum OS {
	WINDOWS,LINUX,MAC_OS;
	
	public string get_json_name() {
		switch (this) {
			case OS.LINUX: return "linux";
			case OS.WINDOWS: return "windows";
			case OS.MAC_OS: return "osx";
		}
		return "linux";
	}
}

class DownloadItem {
	private string url;
	private string path;
	
	public DownloadItem(string url, string path) {
		this.url = url;
		this.path = path;
	}

	public string get_url() {
		return this.url;
	}
	
	public string get_path() {
		return this.path;
	}
}
