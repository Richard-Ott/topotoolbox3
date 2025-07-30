classdef testSnapshot < matlab.perftest.TestCase
    % testSnapshot Snapshot testing using topotoolbox3 as a reference
    % The data for the snapshot tests are available as versioned releases
    % in the TopoToolbox/snapshot_data repository. This repository is added
    % as a submodule to topotoolbox3 at the path tests/snapshots.
    %
    % To obtain the snapshot test data, you should initialize the
    % test/snapshots submodule. If you are cloning the repository for the
    % first time, you can use `git clone --recurse-submodules
    % https://github.com/TopoToolbox/topotoolbox3` to initialize the
    % submodule. If you have already cloned the project you should run `git
    % submodule update --init`. Then, download the `snapshot_data.tar.gz` 
    % archive from the latest release of the snapshot_data repository and 
    % extract it within the tests/snapshots directory. You should now have
    % a `data/` directory that contains all of the existing snapshot data
    % files.
    %
    % If you need to pull in new changes from the TopoToolbox/topotoolbox3
    % repository that include changes to the snapshots submodule, you
    % should run `git submodule update` after running `git pull` or run
    % `git pull --recurse-submodules` to always pick up the latest
    % submodule changes.
    % 
    % See the Pro Git page on submodules for more guidance:
    % https://git-scm.com/book/en/v2/Git-Tools-Submodules
    %
    % The basic strategy for these tests:
    %
    % 1. The snapshot tests are run just like a normal test for
    %    topotoolbox3.
    % 2. If there is no data for a given test in the tests/snapshots
    %    directory, the test will create it.    
    % 3. If the appropriate data does exist in the tests/snapshots
    %    directory, they will be compared against the results computed
    %    here. The test will fail if the saved version and the computed
    %    version do not match according to the test. 
    % 4. Snapshotting of results must currently be done manually. If you
    %    want to save the results of a test run:
    %    - The updated snapshots will be saved in the tests/snapshots/data
    %      directory.
    %    - Run `sha256sum` or its equivalent on the snapshot data to record
    %      the SHA256 checksums of each of the snapshot data files. Store 
    %      the results in the sha256sum.txt file in the snapshot_data
    %      repository.
    %    - Commit your changes to sha256sum.txt.
    %    - Push the commit to your fork of TopoToolbox/snapshot_data and
    %      make a pull request
    %    - Once the pull request is merged, make a new release of the
    %      snapshot_data repository and attach a gzipped tar file
    %      containing the `tests/snapshots/data` directory with the new
    %      snapshots.
    %    - Pull the new changes into the submodule by going into the
    %      submodule directory and running the appropriate `git pull`
    %      command.
    %    - If you now move to the topotoolbox3 directory and run `git
    %      status` you should see changes to tests/snapshots, but not
    %      to any of the files within that directory. `git add
    %      tests/snapshots` and `git commit` to record the new
    %      snapshot_data commit for the submodule.
    %    - Now push the topotoolbox3 commit to your fork and make a pull
    %      request. Once it is merged, you should be able to run `git pull
    %      --recurse-submodules` to pull the new changes including the new
    %      snapshot data into your main branch.
    % 5. If a change to the results is expected, delete the appropriate
    %    snapshot from the tests/snapshots directory before running the
    %    test and create a new one following the procedure outlined above.
    %
    % Be careful when adding new tests requiring floating point comparison.
    % These tests may work on your own machine, but might vary across
    % different operating systems and hardware architectures. Use
    % approximate comparisons where appropriate.

    properties
        dem
    end

    properties (ClassSetupParameter)
        dataset
    end

    properties (TestParameter)
        uselibtt = {false, true};
    end

    methods (TestParameterDefinition,Static)
        function dataset = findDatasets()
            % Find all the existing snapshot datasets
            [~,available_datasets,~] = fileparts([{},struct2table(dir("snapshots/data/*/dem.tif")).folder]);
            if ~isempty(available_datasets)
                dataset = available_datasets;
            else
                error("No snapshots found.");
            end
        end
    end

    methods (TestClassSetup)
        % Shared setup for the entire test class
        function read_data(testCase,dataset)
            data_file = fullfile("snapshots/data/",dataset,"dem.tif");
            testCase.dem = GRIDobj(data_file);
        end
    end

    methods (TestMethodSetup)
        % Setup for each test
    end

    methods (Test)
        % Test methods
        function fillsinks(testCase,dataset, uselibtt)
            testCase.startMeasuring();
            demf = testCase.dem.fillsinks(uselibtt=uselibtt);
            testCase.stopMeasuring();

            result_file = fullfile("snapshots/data/",dataset,"fillsinks.tif");

            if ~isfile(result_file) && ~uselibtt
                % Write the result to the directory
                demf.GRIDobj2geotiff(result_file);
            else
                demf_result = GRIDobj(result_file);
                testCase.verifyEqual(demf_result.Z,demf.Z);
            end
        end

        function identifyflats(testCase, dataset, uselibtt)
            demf = testCase.dem.fillsinks(uselibtt=uselibtt);

            testCase.startMeasuring();
            [FLATS, SILLS, CLOSED] = demf.identifyflats(uselibtt=uselibtt);
            testCase.stopMeasuring();

            flats_file = fullfile("snapshots/data/",dataset,"identifyflats_flats.tif");
            sills_file = fullfile("snapshots/data/",dataset,"identifyflats_sills.tif");
            closed_file = fullfile("snapshots/data/",dataset,"identifyflats_closed.tif");

            if ~isfile(flats_file) && ~uselibtt
                FLATS.GRIDobj2geotiff(flats_file);
            else
                flats_result = GRIDobj(flats_file);
                testCase.verifyEqual(logical(flats_result.Z),FLATS.Z);
            end

            if ~isfile(sills_file) && ~uselibtt
                SILLS.GRIDobj2geotiff(sills_file);
            else
                sills_result = GRIDobj(sills_file);
                testCase.verifyEqual(logical(sills_result.Z),SILLS.Z);
            end

            if ~isfile(closed_file) && ~uselibtt
                CLOSED.GRIDobj2geotiff(closed_file);
            else
                closed_result = GRIDobj(closed_file);
                testCase.verifyEqual(logical(closed_result.Z),CLOSED.Z);
            end
        end

        function acv(testCase,dataset)
            testCase.startMeasuring();
            A = testCase.dem.acv();
            testCase.stopMeasuring();

            result_file = fullfile("snapshots/data/",dataset,"acv.tif");

            if ~isfile(result_file)
                % Write the result to the directory
                A.GRIDobj2geotiff(result_file);
            else
                demf_result = GRIDobj(result_file);
                testCase.verifyEqual(demf_result.Z,A.Z);
            end
        end

        function auxtopo(testCase, dataset, uselibtt)
            D = testCase.dem;

            testCase.startMeasuring();
            D.Z = single(createAuxiliaryTopo(testCase.dem, ...
                'preprocess', 'carve', ...
                'uselibtt',uselibtt, ...
                'verbose', false, ...
                'internaldrainage',false));
            testCase.stopMeasuring();

            result_file = fullfile("snapshots/data/",dataset,"auxtopo.tif");

            if ~isfile(result_file) && ~uselibtt
                D.GRIDobj2geotiff(result_file);
            else
                D_result = GRIDobj(result_file);
                testCase.verifyEqual(D_result.Z, D.Z);
            end
        end

        function hillshade(testCase, dataset, uselibtt)
            testCase.startMeasuring();
            H = hillshade(testCase.dem,"uselibtt",uselibtt);
            testCase.stopMeasuring();

            result_file = fullfile("snapshots/data/", dataset, "hillshade.tif");

            if ~isfile(result_file) && ~uselibtt
                H.GRIDobj2geotiff(result_file)
            else
                H_result = GRIDobj(result_file);
                testCase.verifyEqual(H_result.Z, H.Z,'AbsTol',single(1e-4));
            end
        end
    end
end
