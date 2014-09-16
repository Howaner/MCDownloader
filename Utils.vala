class Utils {
	
	public static OS get_os() {
		return OS.LINUX;
	}
	
	public static string check_windows_path(string path) {
		if (get_os() != OS.WINDOWS) return path;
		string newPath = path.replace("/", "\\");
		return newPath;
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
			string server_url = (librarie_object.has_member("url")) ? librarie_object.get_string_member("url") : "https://libraries.minecraft.net";
			string librarie_url = "%s/%s".printf(server_url, get_library_path(librarie_name));
			string librarie_path = check_windows_path("%s/%s".printf(Downloader.instance.folder, get_library_path(librarie_name)));
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
	
	public static string get_library_base_dir(string library_name) {
		string[] split = library_name.split(":");
		return "%s/%s/%s".printf(split[0].replace(".", "/"), split[1], split[2]);
	}
	
	public static string get_library_path(string library_name) {
		string[] split = library_name.split(":");
		string file_name = "%s-%s.jar".printf(split[1], split[2]);

		return "%s/%s".printf(get_library_base_dir(library_name), file_name);
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
