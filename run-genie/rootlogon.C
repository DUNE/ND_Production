{
    // Print confirmation (optional)
    std::cout << "Loading libraries to read gtree from GHEP files..." << std::endl;

    // Path to your compiled libraries (adjust as needed)
    //const char* lib_path = "/storage/gpfs_data/neutrino/users/gsantoni/ND_Production/run-genie";
    

    // Load ROOT dependencies first (if needed)
    gSystem->Load("libPhysics");
    gSystem->Load("libTree");

    // Load all .so libraries (explicitly list them)
    const std::vector<TString> libraries = {
        "/opt/generators/genie/lib/libGFwUtl-3.04.00.so"
    };

    for (const auto& lib : libraries) {
        if (gSystem->Load(lib) < 0) {
            std::cerr << "Error loading " << lib << std::endl;
        }
    }

    // Print all loaded libraries
    std::cout << "\n=== Loaded Libraries ===\n";
    auto libs = gSystem->GetLibraries();
    std::cout<< libs<<"\n";
    std::cout << "======================\n";

}

