"""tiny test case for SDP parsing"""
import unittest
import parseSDP

class SDPTestCase(unittest.TestCase):
    def testSimpleSDP(self):
        sdp = """
#foo
#bar
#CHROM	START	END	FORMAT	129P2_OlaHsd	129S1 SvImJ	129S5SvEvBrd
X	101	110	POS:CL:BP:TY	X:100-110;INS|LINE;REF;H6INS	0	.
"""
        sdpFile = sdp.split("\n")
        svs = list(parseSDP.parse_SDP(sdpFile))
        self.assertEqual(len(svs), 1)
        sv = svs[0]
        self.assertEqual(sv.chrom, 'X')
        self.assertEqual(sv.start, 101)
        self.assertEqual(sv.end, 110)
        self.assertEqual(sv.samples,
                         set(['129P2_OlaHsd', '129S1 SvImJ', '129S5SvEvBrd']))
        self.assertEqual(set(sv.samples_affected()), set(['129P2_OlaHsd']))
        self.assertEqual(sv.breakpoints('129P2_OlaHsd'), ('X', 100, 110))
        self.assertEqual(sv.svClass('129P2_OlaHsd'), 'INS')
        self.assertEqual(sv.svClassDetail('129P2_OlaHsd'), 'LINE')
        self.assertEqual(sv.refined('129P2_OlaHsd'), True)
        self.assertEqual(sv.type('129P2_OlaHsd'), 'H6INS')

if __name__ == '__main__':
    unittest.main()
