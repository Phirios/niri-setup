import unittest
from resize import plan, Refused, transform, tree, commands


class GeometryTests(unittest.TestCase):
    def test_take_all_bypasses_fraction_steps(self):
        before = {'peer':[0,0,600,600], 'active':[0,600,600,600], 'donor':[600,0,600,1200]}
        after, detail = plan(before,'active','right',[0,0,1200,1200],take_all=True)
        self.assertEqual(detail['fraction'],'1')
        self.assertEqual(after['active'],[0,600,1200,600])
        self.assertEqual(after['donor'],[600,0,600,600])

    def test_take_all_refuses_when_no_rectangle_can_remain(self):
        before = {'active':[0,0,600,600], 'donor':[600,0,600,600]}
        with self.assertRaises(Refused):
            plan(before,'active','right',[0,0,1200,600],take_all=True)

    def test_take_all_also_reshapes_a_wide_neighbour(self):
        before = {'peer':[0,0,600,300], 'active':[0,300,600,300], 'donor':[600,0,1000,600]}
        after, detail = plan(before,'active','right',[0,0,1600,600],take_all=True)
        self.assertEqual(detail['mode'],'reshape')
        self.assertEqual(after['active'],[0,300,1600,300])
        self.assertEqual(after['donor'],[600,0,1000,300])

    def test_take_all_respects_remaining_height(self):
        before = {'peer':[0,0,600,190], 'active':[0,190,600,1010], 'donor':[600,0,600,1200]}
        with self.assertRaises(Refused):
            plan(before,'active','right',[0,0,1200,1200],take_all=True)

    def test_take_all_in_all_directions(self):
        original = {'peer':[0,0,600,600], 'active':[0,600,600,600], 'donor':[600,0,600,1200]}
        for direction in ['right','left','up','down']:
            before = {k:transform(r,direction,True) for k,r in original.items()}
            root = transform([0,0,1200,1200],direction,True)
            after, detail = plan(before,'active',direction,root,take_all=True)
            self.assertEqual(detail['mode'],'reshape')
            self.assertEqual(transform(after['active'],direction),[0,600,1200,600])

    def test_shrink_complete_fraction_progression(self):
        before = {'active':[0,0,1600,600], 'neighbour':[1600,0,400,600]}
        for fraction, width in [('3/4',1500),('2/3',4000/3),('1/2',1000),('1/3',2000/3),('1/4',500),('1/5',400)]:
            before, detail = plan(before,'active','right',[0,0,2000,600],shrink=True)
            self.assertEqual(detail['fraction'],fraction)
            self.assertAlmostEqual(before['active'][2],width)
            self.assertEqual(before['active'][0],0)
        with self.assertRaises(Refused):
            plan(before,'active','right',[0,0,2000,600],shrink=True)

    def test_shrink_corresponding_edge_in_all_directions(self):
        original = {'active':[0,0,800,600], 'neighbour':[800,0,400,600]}
        for direction in ['right','left','up','down']:
            before = {k:transform(r,direction,True) for k,r in original.items()}
            root = transform([0,0,1200,600],direction,True)
            after, detail = plan(before,'active',direction,root,shrink=True)
            self.assertEqual(detail['fraction'],'1/2')
            self.assertEqual(transform(after['active'],direction),[0,0,600,600])
            self.assertEqual(transform(after['neighbour'],direction),[600,0,600,600])

    def test_shrink_respects_content_minimum(self):
        before = {'active':[0,0,250,600], 'neighbour':[250,0,750,600]}
        with self.assertRaises(Refused):
            plan(before,'active','right',[0,0,1000,600],(2,6),shrink=True)

    def test_shrink_leaves_separate_row_unchanged(self):
        before = {'peer':[0,0,800,600], 'active':[0,600,800,600],
                  'top':[800,0,400,600], 'bottom':[800,600,400,600]}
        after, detail = plan(before,'active','right',[0,0,1200,1200],shrink=True)
        self.assertEqual(detail['fraction'],'1/2')
        self.assertEqual(after['peer'],before['peer'])
        self.assertEqual(after['top'],before['top'])
        self.assertEqual(after['active'][2],600)
        self.assertEqual(after['bottom'][2],600)

    def test_shorten_tall_neighbour_instead_of_narrowing(self):
        before = {'firefox':[0,0,2400,600], 'active':[0,600,2400,600], 'donor':[2400,0,600,1200]}
        after, detail = plan(before, 'active', 'right', [0,0,3000,1200])
        self.assertEqual(detail['mode'], 'reshape')
        self.assertEqual(after, {'firefox':[0,0,2400,600], 'active':[0,600,3000,600], 'donor':[2400,0,600,600]})

    def test_identical_rule_in_all_four_directions(self):
        original = {'peer':[0,0,2400,600], 'active':[0,600,2400,600], 'donor':[2400,0,600,1200]}
        for direction in ['right','left','up','down']:
            before = {k:transform(r,direction,True) for k,r in original.items()}
            root = transform([0,0,3000,1200],direction,True)
            after, detail = plan(before,'active',direction,root)
            self.assertEqual(detail['mode'],'reshape')
            self.assertEqual(transform(after['active'],direction),[0,600,3000,600])

    def test_half_grows_to_two_thirds(self):
        before = {'active':[0,0,800,600], 'donor':[800,0,800,600]}
        after, detail = plan(before,'active','right',[0,0,1600,600])
        self.assertEqual(detail['fraction'],'2/3')
        self.assertAlmostEqual(after['active'][2],1600*2/3)
        self.assertAlmostEqual(after['donor'][2],1600/3)

    def test_complete_fraction_progression(self):
        before = {'active':[0,0,400,600], 'donor':[400,0,1600,600]}
        for fraction, width in [('1/4',500),('1/3',2000/3),('1/2',1000),('2/3',4000/3),('3/4',1500),('4/5',1600)]:
            before, detail = plan(before,'active','right',[0,0,2000,600])
            self.assertEqual(detail['fraction'],fraction)
            self.assertAlmostEqual(before['active'][2],width)
        with self.assertRaises(Refused):
            plan(before,'active','right',[0,0,2000,600])

    def test_arbitrary_sizes_snap_to_the_next_fraction(self):
        before = {'active':[0,0,550,600], 'donor':[550,0,1450,600]}
        after, detail = plan(before,'active','right',[0,0,2000,600])
        self.assertEqual(detail['fraction'],'1/3')
        self.assertAlmostEqual(after['active'][2],2000/3)

    def test_rounding_does_not_repeat_the_same_fraction(self):
        before = {'active':[0,0,666,600], 'donor':[666,0,1334,600]}
        after, detail = plan(before,'active','right',[0,0,2000,600])
        self.assertEqual(detail['fraction'],'1/2')
        self.assertEqual(after['active'][2],1000)

    def test_stop_on_a_fraction_instead_of_an_arbitrary_pixel_limit(self):
        before = {'active':[0,0,600,1200], 'donor':[600,0,600,1200]}
        for fraction in ['2/3','3/4','4/5']:
            before, detail = plan(before,'active','right',[0,0,1200,1200])
            self.assertEqual(detail['fraction'],fraction)
        self.assertAlmostEqual(before['donor'][2],240)
        with self.assertRaises(Refused):
            plan(before,'active','right',[0,0,1200,1200])

    def test_grow_leaves_separate_row_unchanged(self):
        before = {'peer':[0,0,600,600], 'active':[0,600,600,600],
                  'top':[600,0,800,600], 'bottom':[600,600,800,600]}
        after, detail = plan(before,'active','right',[0,0,1400,1200])
        self.assertEqual(set(detail['receivers']), {'active'})
        self.assertEqual(after['peer'],before['peer'])
        self.assertEqual(after['top'],before['top'])
        self.assertGreater(after['active'][2],before['active'][2])

    def test_tall_neighbour_requires_shared_divider_peers(self):
        before = {'peer':[0,0,600,600], 'active':[0,600,600,600], 'donor':[600,0,800,1200]}
        after, detail = plan(before,'active','right',[0,0,1400,1200])
        self.assertEqual(set(detail['receivers']),{'peer','active'})
        self.assertEqual(after['peer'][2],after['active'][2])

    def test_only_active_row_grows_in_all_directions(self):
        original = {'peer':[0,0,600,600], 'active':[0,600,600,600],
                    'top':[600,0,800,600], 'bottom':[600,600,800,600]}
        for direction in ['right','left','up','down']:
            before = {k:transform(r,direction,True) for k,r in original.items()}
            root = transform([0,0,1400,1200],direction,True)
            after, _ = plan(before,'active',direction,root)
            self.assertEqual(after['peer'],before['peer'])
            self.assertEqual(after['top'],before['top'])

    def test_minimum_includes_gaps_and_borders(self):
        before = {'active':[0,0,750,1200], 'donor':[750,0,250,1200]}
        with self.assertRaises(Refused):
            plan(before,'active','right',[0,0,1000,1200],(2,6))

    def test_fraction_progression_in_all_directions(self):
        original = {'active':[0,0,600,600], 'donor':[600,0,600,600]}
        for direction in ['right','left','up','down']:
            before = {k:transform(r,direction,True) for k,r in original.items()}
            root = transform([0,0,1200,600],direction,True)
            after, detail = plan(before,'active',direction,root)
            self.assertEqual(detail['fraction'],'2/3')
            self.assertEqual(transform(after['active'],direction),[0,0,800,600])

    def test_no_neighbour_is_a_noop(self):
        with self.assertRaises(Refused):
            plan({'active':[0,0,600,600]},'active','right',[0,0,600,600])

    def test_no_room_is_a_noop(self):
        with self.assertRaises(Refused):
            plan({'active':[0,0,600,600],'donor':[600,0,200,600]},'active','right',[0,0,800,600])

    def test_reject_holes(self):
        with self.assertRaises(Refused):
            tree({'a':[0,0,600,600], 'b':[600,600,600,600]})

    def test_rebuild_selects_correct_direction_and_restores_focus(self):
        rects = {'top_left':[0,0,600,600], 'top_right':[600,0,600,600], 'active':[0,600,1200,600]}
        batch = commands(rects,'active')
        self.assertIn('run(hl.dsp.layout("preselect d"))',batch)
        self.assertIn('run(hl.dsp.layout("preselect r"))',batch)
        self.assertEqual(batch[-1],'run(hl.dsp.focus({window="address:active"}))')

    def test_rebuild_keeps_windows_on_their_workspace(self):
        rects = {'a':[0,0,600,600], 'b':[600,0,600,600]}
        batch = '\n'.join(commands(rects,'a'))
        self.assertNotIn('window.move',batch)
        self.assertNotIn('workspace',batch)
        self.assertIn('window.float({action="on",window="address:b"})',batch)
        self.assertIn('window.float({action="off",window="address:b"})',batch)


if __name__ == '__main__':
    unittest.main()
