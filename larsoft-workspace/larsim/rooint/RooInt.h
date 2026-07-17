/*****************************************************************************
 * Project: RooFit  (vendored into larsim for conda packaging)               *
 * Package: RooFitCore                                                       *
 *    File: RooInt.h (verbatim from ROOT v6-28-12, Compare() inlined)        *
 * Authors:                                                                  *
 *   WV, Wouter Verkerke, UC Santa Barbara, verkerke@slac.stanford.edu       *
 *   DK, David Kirkby,    UC Irvine,         dkirkby@uci.edu                 *
 *                                                                           *
 * Copyright (c) 2000-2005, Regents of the University of California          *
 *                          and Stanford University. All rights reserved.    *
 *                                                                           *
 * Redistribution and use in source and binary forms,                        *
 * with or without modification, are permitted according to the terms        *
 * listed in LICENSE (http://roofit.sourceforge.net/license.txt)             *
 *****************************************************************************/

// RooInt is the integer analogue of RooFitCore's RooDouble. ROOT *removed*
// RooInt after 6.28 (RooDouble, used identically by larsim, still ships in
// 6.36), but larsim's PhotonLibrary persists photon-library voxel metadata
// (NVoxels, NChannels, NDivX/Y/Z) as RooInt objects inside the library ROOT
// file. We re-supply the class verbatim from ROOT v6-28-12 -- same class name
// and ClassDef version 1 -- so that existing photon-library files stay
// readable and newly written ones stay compatible with stock larsoft. The only
// change from upstream is that Compare() is defined inline here (upstream put
// it in RooInt.cxx) so no extra translation unit is needed; a rootcling
// dictionary is generated alongside (see PhotonPropagation/CMakeLists.txt).

#ifndef ROO_INT
#define ROO_INT

#include "Rtypes.h"
#include "TNamed.h"

class RooInt : public TNamed {
public:
  RooInt() : _value(0) {}
  RooInt(Int_t value) : TNamed(), _value(value) {}
  RooInt(const RooInt& other) : TNamed(other), _value(other._value) {}
  ~RooInt() override {}

  // Int_t cast operator
  inline operator Int_t() const { return _value; }
  RooInt& operator=(Int_t value)
  {
    _value = value;
    return *this;
  }

  // Sorting interface
  Int_t Compare(const TObject* other) const override
  {
    const RooInt* otherInt = dynamic_cast<const RooInt*>(other);
    return otherInt ? ((_value > otherInt->_value) ? 1 : ((_value == otherInt->_value) ? 0 : -1))
                    : 0;
  }
  bool IsSortable() const override { return true; }

protected:
  Int_t _value; ///< Payload
  ClassDefOverride(RooInt, 1) // Container class for Int_t
};

#endif
