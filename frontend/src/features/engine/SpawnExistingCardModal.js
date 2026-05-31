import React, {useContext, useEffect, useState} from "react";
import ReactModal from "react-modal";
import { useDispatch, useSelector } from "react-redux";
import useProfile from "../../hooks/useProfile";
import { setShowModal, setTyping } from "../store/playerUiSlice";
import { useGameL10n } from "./hooks/useGameL10n";
import BroadcastContext from "../../contexts/BroadcastContext";
import { usePlugin } from "./hooks/usePlugin";
import { useGameDefinition } from "./hooks/useGameDefinition";
import { useDoActionList } from "./hooks/useDoActionList";
import { useImportLoadList } from "./hooks/useImportLoadList";
import { Z_INDEX } from "./functions/common";

// Helper function to transform cardDb structure from {sides: {A: {...}}} to {A: {...}}
const transformCardDb = (rawCardDb) => {
  const transformed = {};
  for (const [cardId, card] of Object.entries(rawCardDb)) {
    if (card.sides) {
      transformed[cardId] = card.sides;
    } else {
      transformed[cardId] = card;
    }
  }
  return transformed;
};

// Import local cardDb for fallback (for development)
let LocalCardDb = {};
let cardDbLoadPromise = null;

// Load cardDb lazily from public folder
const loadCardDb = async () => {
  if (cardDbLoadPromise) return cardDbLoadPromise;

  cardDbLoadPromise = (async () => {
    try {
      const response = await fetch(process.env.PUBLIC_URL + "/cardDb.json");
      if (!response.ok) {
        throw new Error(`Failed to load cardDb: ${response.status}`);
      }
      const rawCardDb = await response.json();

      // Transform the card data structure from {sides: {A: {...}}} to {A: {...}}
      LocalCardDb = transformCardDb(rawCardDb);
      return LocalCardDb;
    } catch (e) {
      console.warn("Failed to load local cardDb:", e);
      return {};
    }
  })();

  return cardDbLoadPromise;
};

const RESULTS_LIMIT = 150;

export const SpawnExistingCardModal = React.memo(({}) => {
  const {gameBroadcast, chatBroadcast} = useContext(BroadcastContext);
    const dispatch = useDispatch();
    const gameL10n = useGameL10n();
    const myUser = useProfile();
    const playerN = useSelector(state => state?.playerUi?.playerN);
    const plugin = usePlugin();
    const gameDef = useGameDefinition();
    const loadList = useImportLoadList();
    const doActionList = useDoActionList();

    const [spawnFilteredIDs, setSpawnFilteredIDs] = useState([]);
    const [cardDb, setCardDb] = useState({});
    const [loadGroupId, setLoadGroupId] = useState(gameDef?.spawnExistingCardModal?.loadGroupIds[0])

    // Load local cardDb on component mount if plugin.card_db is not available
    useEffect(() => {
      if (plugin?.card_db && Object.keys(plugin.card_db).length > 0) {
        // Transform plugin.card_db to the expected format
        const transformedCardDb = transformCardDb(plugin.card_db);
        setCardDb(transformedCardDb);
        setSpawnFilteredIDs(Object.keys(transformedCardDb));
      } else {
        // Fallback to loading local cardDb from public folder
        loadCardDb().then((loadedCardDb) => {
          setCardDb(loadedCardDb);
          setSpawnFilteredIDs(Object.keys(loadedCardDb));
        });
      }
    }, [plugin]);

    // Don't render the table while loading cardDb
    if (Object.keys(cardDb).length === 0) {
      return (
        <ReactModal
          closeTimeoutMS={200}
          isOpen={true}
          onRequestClose={() => {
            dispatch(setShowModal(null));
            dispatch(setTyping(false));
          }}
          contentLabel="Spawn a card"
          overlayClassName="fixed inset-0 bg-black-50"
          className="insert-auto overflow-auto p-5 bg-gray-700 border mx-auto my-12 rounded-lg outline-none max-h-3/4"
          style={{
            overlay: {
              zIndex: Z_INDEX.Modal
            },
            content: {
              width: "40vw",
              maxWidth: "62vw",
              minWidth: "43vw",
              maxHeight: "85dvh",
              overflowY: "scroll",
            }
          }}>
          <h1 className="mb-2 text-white">Loading cards...</h1>
        </ReactModal>
      );
    }

    const numCols = gameDef.spawnExistingCardModal?.columnProperties?.length || 2;
    const vwPerCol = 8;

    const handleGroupIdChange = (event) => {
      setLoadGroupId(event.target.value);
    }

    const handleSpawnClick = (cardId) => {
        const cardDetails = cardDb[cardId];
        if (!cardDetails || !playerN) return;
        const cardList = [{'databaseId': cardId, 'quantity': 1, 'loadGroupId': loadGroupId}]
        loadList(cardList);
        doActionList(["LOG", "$ALIAS_N", " spawned "+cardDetails["A"]["name"]+"."], `Spawn card ${cardId}: ${cardDetails["A"]["name"]}`, true);
    }

    const handleSpawnTyping = (event) => {
        const filteredName = event.target.value;
        const filteredIDs = [];
        Object.keys(cardDb).forEach((cardID) => {
          const cardRow = cardDb[cardID]
          const sideA = cardRow["A"]
          if (!sideA || !sideA["name"]) return;
          const cardName = sideA["name"];
          if (cardName.toLowerCase().includes(filteredName.toLowerCase())) {
            filteredIDs.push(cardID);
          }
        })
        setSpawnFilteredIDs(filteredIDs);
    }

    return(
      <ReactModal
        closeTimeoutMS={200}
        isOpen={true}
        onRequestClose={() => {
          dispatch(setShowModal(null));
          dispatch(setTyping(false));
        }}
        contentLabel="Spawn a card"
        overlayClassName="fixed inset-0 bg-black-50"
        className="insert-auto overflow-auto bg-gray-800 border border-gray-600 mx-auto mt-12 rounded-lg outline-none max-h-3/4"
        style={{
          overlay: {
            zIndex: Z_INDEX.Modal
          },
          content: {
            width: vwPerCol*numCols+2+"vw",
            maxWidth: "62vw",
            minWidth: "43vw",
            maxHeight: "85dvh",
            overflowY: "auto",
          }
        }}>
        <div style={{padding: "20px 24px 8px 24px", borderBottom: "1px solid #374151"}}>
          <h1 style={{margin: 0, fontSize: "1.25rem", fontWeight: 600, color: "white", letterSpacing: "-0.01em"}}>
            Spawn Card
          </h1>
          <p style={{margin: "4px 0 0 0", fontSize: "0.8rem", color: "#9ca3af"}}>
            Search and add cards to the game
          </p>
        </div>
        <div style={{padding: "12px 24px 20px 24px"}}>
        <div><span className="text-white">Load group: </span>
          <select className="form-control mb-1" style={{width:"35%"}} id={"loadGroupId"} name={"loadGroupId"} onChange={(event) => handleGroupIdChange(event)}>
            {gameDef?.spawnExistingCardModal?.loadGroupIds?.map((groupId,_groupIndex) => (
              <option key={groupId} value={groupId}>{gameL10n(gameDef?.groups?.[groupId]?.label)}</option>
            ))}
          </select>
        </div>
        <input 
          autoFocus
          style={{width:"50%"}} 
          type="text"
          id="name" 
          name="name" 
          className="mb-6 mt-5 rounded" 
          placeholder=" Card name..." 
          onChange={handleSpawnTyping}
          onFocus={event => dispatch(setTyping(true))}
          onBlur={event => dispatch(setTyping(false))}/>
        {(spawnFilteredIDs.length) ? 
          (spawnFilteredIDs.length>RESULTS_LIMIT) ?
            <div className="text-white">Too many results</div> :
            <table 
              className="table-fixed rounded-lg w-full overflow-h-scroll"
              style={{
                width: vwPerCol*numCols+"vw",
                minWidth: "40vw",
              }
              }>
              <thead>
                <tr className="text-white bg-gray-800">
                  {gameDef.spawnExistingCardModal?.columnProperties?.map((prop, colindex) => {
                    const propLabel = gameDef.faceProperties[prop]?.label ? gameL10n(gameDef.faceProperties[prop].label) : prop;
                    return(
                      <th key={colindex} className="p-1">{propLabel}</th>
                    )
                  })}
                </tr>
              </thead>
              {spawnFilteredIDs.map((cardId, rowindex) => {
                const card = cardDb[cardId];
                const sideA = cardDb[cardId]?.["A"];
                if (!sideA) return null;
                return(
                  <tr key={rowindex} className="bg-gray-600 text-white cursor-pointer hover:bg-gray-500 hover:text-black" onClick={() => handleSpawnClick(cardId)}>
                    {gameDef.spawnExistingCardModal.columnProperties?.map((prop, colindex) => {
                      return(
                        <td key={colindex} className="p-1 break-words">{sideA[prop]}</td>
                      )
                    })}
                  </tr>
                );
              })}
            </table> :
            <div className="text-white">No results</div>
        }
        </div>
      </ReactModal>
    )
})