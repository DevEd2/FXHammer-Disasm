.SUFFIXES:

BINDIR  := bin
OBJDIR  := obj
PADVALUE:= 0xFF
ROMNAME := FXHammer
ROMEXT  := gb

RGBDS   :=
AS      =$(RGBDS)rgbasm
ASFLAGS =
LD      =$(RGBDS)rgblink
LDFLAGS = -p $(PADVALUE)
RGBFIX  :=$(RGBDS)rgbfix
MKDIR   := mkdir

ROM = $(BINDIR)/$(ROMNAME).$(ROMEXT)

.PHONY: all clean rebuild
all: $(ROM)

clean:
	$(RM) $(BINDIR)/* $(OBJDIR)/*

rebuild: clean all

$(BINDIR)/%.$(ROMEXT): $(OBJDIR)/main.obj
	@$(MKDIR) -p $(BINDIR)/
	$(LD) $(LDFLAGS) -n $(BINDIR)/$*.sym -o $@ $< && $(RGBFIX) -v $@

$(OBJDIR)/%.obj: %.asm
	@$(MKDIR) -p $(OBJDIR)/
	$(AS) $(ASFLAGS) -o $@ $<

