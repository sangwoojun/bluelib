BSCFLAGS = -show-schedule -aggressive-conditions 
BSCFLAGS_BSIM = -bdir ./bsim/obj -simdir ./bsim/obj -info-dir ./bsim -fdir ./bsim

BSIM_CPPFILES = bdpi.cpp

bsim: SimTop.bsv $(wildcard ../*.bsv)
	mkdir -p bsim
	mkdir -p bsim/obj
	bsc $(BSCFLAGS) $(BSCFLAGS_BSIM) $(DEBUGFLAGS) -p +:../ -sim -u -g mkSimTop SimTop.bsv  
	bsc $(BSCFLAGS) $(BSCFLAGS_BSIM) $(DEBUGFLAGS) -sim -e mkSimTop -o bsim/obj/bsim bsim/obj/*.ba $(BSIM_CPPFILES) 

clean:
	rm -rf bsim
