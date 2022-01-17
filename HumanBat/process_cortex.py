import matlab.engine
import io
import sys
import os
import pathlib
import mat73
import re
import scipy.signal
import scipy.io
import numpy as np

def extract_cortex_c3d(data_path):
    """
    Python wrapper for extracting C3D data files from cortex

    Parameters
    ----------
    data_path : string
    Path to Generated_C3D_files/ folder from Sky extracted C3D cortex files
    """
    assert os.path.exists(data_path), "{} does not exist!".format(data_path)

    folder_name = pathlib.PurePath(data_path).name

    # Start matlab engine
    eng = matlab.engine.start_matlab()

    # Add LoggerDataProcessing Path
    # Path is absolute
    QbatsPath = os.path.join(os.path.dirname(os.path.realpath(__file__)),'qbats')
    QbatsPath = eng.genpath(QbatsPath)

    eng.addpath(QbatsPath, nargout=0)

    print("Running cortex C3D extraction script... ")
    print(data_path)
    eng.extract_tracking_data(data_path,nargout=0)

    print("Cortex C3D Extraction complete!")
