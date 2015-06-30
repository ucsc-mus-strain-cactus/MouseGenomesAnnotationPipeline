include defs.mk

all: ${lodTxtFile}

${lodTxtFile}: ${halBrowserFile}
	@mkdir -p $(dir $@)
	halLodInterpolate.py --inMemory --numProc 5 --minLod0 8000 --outHalDir ${lodDir} ${halBrowserFile} $@.${tmpExt}
	mv -f $@.${tmpExt} $@
