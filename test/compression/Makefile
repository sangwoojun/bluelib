ROOTDIR=../../
BSVPATH=$(ROOTDIR)/src:$(ROOTDIR)/src/compression 

BSIM_DIR=./bsim/
BSIM_CPPFILES=bdpi.cpp

BSCFLAGS = -show-schedule -aggressive-conditions 
BSCFLAGS_BSIM = -bdir $(BSIM_DIR) -vdir $(BSIM_DIR) -simdir $(BSIM_DIR) -info-dir $(BSIM_DIR) -fdir $(BSIM_DIR) -D BSIM -l pthread

all:
	mkdir -p $(BSIM_DIR)
	bsc $(BSCFLAGS) $(BSCFLAGS_BSIM) -p +:$(BSVPATH) -sim -u -g mkLZAHBench LZAHBench.bsv 
	bsc $(BSCFLAGS) $(BSCFLAGS_BSIM) -sim -e mkLZAHBench -o $(BSIM_DIR)/bsim $(BSIM_DIR)/*.ba $(BSIM_CPPFILES)

	
