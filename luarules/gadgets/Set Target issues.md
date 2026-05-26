Set Target issues
=================

A lot of these are questions of computational cost. By the late game period on 8v8s, we have players with 2500 fighters attacking into walls of 2500+ enemy fighters, and Set Target cannot keep up. We need to prevent crashes at this stage by placing limits in front of them.

Some others are friction in the design that we will not be able to remove. That's okay.

# Set target wants/needs

## Principle issues

1. Set Target performs around O(N ^ 2 + N) updates per frame, worst-case. This is "lots".
2. We perform inefficient adding operations, often repeating an identical spatial search.
3. We perform inefficient remove operations, sometimes resending a full list to unsynced.
4. Because it sits aside the command queue, Set Target competes for targeting precedence.
5. Set Target does not prevent autotargeting, even when the priority target is reachable.

## Detailed list of issues

1. Attack, Fire at Will, Fight, and Guard/Return Fire retaliation compete with Set Target.
2. The active target in the list has to be maintained constantly.
3. The order of target precedence across various sources is not fully determined.
4. Dropping autotargets often does not work. They need to be "replaced", not "cleared".
5. Set Target forms a separate queue from the command queue, the "target list", which adds double-work.
6. `table.remove` is slow but the target list's priority order requires maintaining the sort.
7. The initial order of the Set Target list is always left to right, top to bottom. This sucks.
8. Untargetable units (even untargetable when radar dots) can be added to the target lists.
9. Because we do not check our selected units or their targetable types before or during the command.
10. ~~The command does not deduplicate when reissued (fixed by becoming non-queuing).~~
11. Each unit's target list has to be searched for dead, unseen, or captured enemies.
12. The sync between synced and unsynced spaces adds overhead and ~~dup~~triplication.
13. The batched send to unsynced has a stride of 8. It can compress to 5 sent, 4 received.
14. The criteria for always-seen units and their positions might not match unit ghosts.
15. The command processing reissues commands; it should just process them into targets.
16. Large unit selections that issue Set Target commands with a large radius do repetitive work.
17. The target list can have more-or-less unlimited length.
18. Updates to the target list tend to apply to all list items following a changed item.
19. The current way targets are cleared with Stop does not always remove them in unsynced.
20. Unit rules params are not always unset (by setting to nil/none).
21. During updates, invalid targets are removed from unit lists. Each removal triggers other changes.
22. Invalid targets are not cached during this. Each target list retests each targetID.
23. Appending targets already in the target list does not update ignoreStop and userTarget.
24. Targets are sometimes dropped when they do not need to be. Seems basically fine, though.
25. No Shutdown behavior for gadget global functions. Not a big deal so far.
26. Please, please just let me rewrite processCommand so that it is pretty.
27. Cancel Target's ICON type expects 0 parameters but accepts 0, 1, or 3.
28. The command cancel radius can cancel only one command before returning.
29. Unit targets within the command cancel radius are not removed from the target list.
30. Handling queueing commands in AllowCommand is not a good approach. Swap this out with UnitCommand.
31. UnitAutoTargetRange needs to be implemented with a stub in gadgets.lua, then can be used to block.
32. Team alliances are easy to cache before checking for captured units during the target list updates.
33. Write a more efficient allied/invalid target removal.
34. Target lost results are easy to cache before checking unseen units during the target list updates.
35. Write a more efficient unseen/invalid target removal.
36. Don't check targeting on frames when other target list update sweeps are being done, too.
37. Queue sending any batched data to unsynced until after target list update sweeps are done.
38. Use rolled arrays in unsynced for lighter, faster updates. We already send the data rolled.
39. Use a gradual draw backoff/skip in drawDecorations to skip extreme target counts.
40. Terrain deformation does not update Set Target map positions.
41. I have not even looked at Set Target Type. I don't want to. Do not make me do this yet.
42. No docs, and the comments and code are ugly. Real and serious and not fake problem.
43. Remove the internal/user distinction; there is effectively no barrier between the two.
44. Late-add of `sent` key to size-4 target tables rehashes the tables and sets them to size 8.
45. We should start deprecating `CMD.DGUN` for `CMD.MANUALFIRE`.
46. Shield weapons, manual fire weapons, and slaved weapons are included in updates.
47. Multi-weapon sets are included, like the smart weapons, which seems thornier.
48. Water weapons are not quite handled properly with positional targets.

