class Downloader {
	public static Downloader? instance = null;
	public string folder = "";
	
	private Gee.List<DownloadItem> download_items = new Gee.ArrayList<DownloadItem>();
	private int akt_download = 0;
	private int next_download_id = 0;
	public MainLoop? loop = null;
	public signal void download_finished(string progressName);
	public Gee.List<string> download_errors = new Gee.ArrayList<string>();
	
	public Downloader(string folder) {
		this.folder = folder;
		instance = this;
		
		/// Downloade Informationen
		print("== Informationen werden heruntergeladen ==\n");
		Gee.List<string>? versions;

		try {
			// Minecraft Versionen
			versions = Utils.get_versions();
			if (versions == null)
				throw new Error(Quark.from_string("Failed to Download MC Versions!"), 0, "Failed to Download MC Versions!");
			print("== Informationen heruntergeladen ==\n");
		} catch (Error e) {
			print("Fehler beim Herunterladen der Informationen: %s\n".printf(e.message));
			return;
		}
		
		download_finished.connect((download_name) => {
			if (download_name == "Json") {
				//Minecraft Dateien
				Gee.List<DownloadItem> version_files = new Gee.ArrayList<DownloadItem>();
				for (int i=0; i<versions.size; i++) {
					string version = versions.get(i);
					try {
						Gee.List<DownloadItem>? files = Utils.get_version_files(version);
						if (files == null)
							throw new Error(Quark.from_string("Failed to get infos from Version %s".printf(version)), 0, "Failed to get infos from Version %s".printf(version));
						for (int y=0; y<files.size; y++) {
							version_files.add(files.get(y));
						}
					} catch (Error e) {
						print("-> Fehler beim Herunterladen der Version %s: %s\n".printf(version, e.message));
						continue;
					}
				}
				
				this.akt_download = 0;
				this.next_download_id = 0;
				this.download_items = version_files;
				print("== Downloade Versionen ==\n");
				this.download("Versionen");
			} else if (download_name == "Versionen") {
				print("=== Download vollständig! ===\n");
				print("\n");
				if (this.download_errors.size > 0) {
					print("Fehler:\n");
					for (int i = 0; i < this.download_errors.size; i++) {
						print("- %s\n".printf(this.download_errors.get(i)));
					}
				}
				loop.quit();
			} else
				loop.quit();
		});
		
		// Downloade Assets
		this.akt_download = 0;
		this.next_download_id = 0;
		this.download_items = new Gee.ArrayList<DownloadItem>();
		for (int i=0; i < versions.size; i++) {
			string version = versions.get(i);
			this.download_items.add(new DownloadItem("https://s3.amazonaws.com/Minecraft.Download/versions/%s/%s.json".printf(version, version), "%s/versions/%s/%s.json".printf(Downloader.instance.folder, version, version)));
		}
		print("== Downloade Json Dateien ==\n");
		loop = new MainLoop();
		this.download("Json");
		loop.run();
	}
	
	public void download(string progressName = "NoName") {
		if (this.akt_download == 0) this.next_download_id += 1;
		int prozent = Utils.get_prozent(this.akt_download, this.download_items.size);
			
		if (this.akt_download >= this.download_items.size) {
			//Download abgeschlossen
			print("=== Download \"" + progressName + "\" abgeschlossen! ===\n");
			this.download_finished(progressName);
			return;
		}
		
		DownloadItem download_item = this.download_items.get(this.akt_download);
		string url = download_item.get_url();
		string path = download_item.get_path();
		Utils.check_path(path);
		File url_file = File.new_for_uri(url);
		File path_file = File.new_for_path(path);
		if (path_file.query_exists()) {
			this.akt_download++;
			download(progressName);
			return;
		}
		
		if (this.download_errors.contains(url)) {
			this.akt_download++;
			download(progressName);
			return;
		}
		print("%s: Downloade %s".printf(prozent.to_string()+"%", path_file.get_basename()));
		url_file.copy_async.begin(path_file, 0, Priority.DEFAULT, null, null, (obj, res) => {
			try {
				url_file.copy_async.end(res);
				print(" Fertig!\n");
			} catch (Error e) {
				stdout.printf (" Error (%s)\n", e.message);
				this.download_errors.add(url);
			}
			this.akt_download += 1;
			download(progressName);
		});
	}
	
	public static int main(string[] args) {
		string folder_path = Environment.get_current_dir();
		if (args.length >= 2) {
			string folder = "";
			for (int i=1; i<args.length; i++) {
				if (folder_path != "") folder_path += " ";
				folder += args[i];
			}
			if (folder != "") {
				File file = File.new_for_path(folder_path);
				if (!file.query_exists() || file.query_file_type(FileQueryInfoFlags.NOFOLLOW_SYMLINKS) != FileType.DIRECTORY) {
					print("Ordner %s nicht gefunden!\n".printf(folder_path));
					return 1;
				}
				folder_path = folder;
			}
		}
		new Downloader(folder_path);
		return 0;
	}
}
